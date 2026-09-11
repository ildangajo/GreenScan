/**
 * 클라이언트 사전 블러 체크 (api-spec.md 2.3)
 *
 * POST /api/v1/photos/analyze는 이 체크를 통과한 사진에 대해서만 호출된다.
 * 라플라시안 분산(Laplacian variance)이 낮을수록 사진이 흐릴 가능성이 높다는
 * 고전적인 블러 판정 방식을 사용한다. 네트워크 왕복 없이 브라우저에서 즉시
 * 재촬영 안내를 띄우기 위한 용도이며, 서버 쪽 사진 품질 판정(photo_quality)을
 * 대체하지 않는다.
 */

export interface GrayscaleSource {
  data: Uint8ClampedArray;
  width: number;
  height: number;
}

const LAPLACIAN_KERNEL = [
  [0, 1, 0],
  [1, -4, 1],
  [0, 1, 0],
];

export function toGrayscale({ data, width, height }: GrayscaleSource): Float64Array {
  const gray = new Float64Array(width * height);
  for (let i = 0; i < width * height; i++) {
    const r = data[i * 4];
    const g = data[i * 4 + 1];
    const b = data[i * 4 + 2];
    gray[i] = 0.299 * r + 0.587 * g + 0.114 * b;
  }
  return gray;
}

/** 그레이스케일 이미지에 3x3 라플라시안 커널을 적용한 응답값의 분산을 구한다. */
export function laplacianVariance(source: GrayscaleSource): number {
  const { width, height } = source;
  if (width < 3 || height < 3) {
    throw new Error("블러 체크에는 최소 3x3 크기의 이미지가 필요합니다.");
  }

  const gray = toGrayscale(source);
  const responseCount = (width - 2) * (height - 2);
  const responses = new Float64Array(responseCount);
  let index = 0;

  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      let sum = 0;
      for (let ky = -1; ky <= 1; ky++) {
        for (let kx = -1; kx <= 1; kx++) {
          const weight = LAPLACIAN_KERNEL[ky + 1][kx + 1];
          if (weight === 0) continue;
          sum += weight * gray[(y + ky) * width + (x + kx)];
        }
      }
      responses[index++] = sum;
    }
  }

  let mean = 0;
  for (let i = 0; i < responses.length; i++) mean += responses[i];
  mean /= responses.length;

  let variance = 0;
  for (let i = 0; i < responses.length; i++) {
    const diff = responses[i] - mean;
    variance += diff * diff;
  }
  return variance / responses.length;
}

/**
 * 정책 확정 필요 (제안값): 흐림 판정 임계값.
 * OpenCV 블러 감지 튜토리얼 등에서 흔히 쓰이는 기본값을 가져왔으나, 실제
 * 서비스에서 촬영되는 창호/벽체 사진 샘플로 팀 검증 후 조정해야 한다.
 */
export const DEFAULT_BLUR_VARIANCE_THRESHOLD = 100;

export function isBlurryVariance(
  variance: number,
  threshold: number = DEFAULT_BLUR_VARIANCE_THRESHOLD,
): boolean {
  return variance < threshold;
}

export interface BlurCheckResult {
  isBlurry: boolean;
  variance: number;
  threshold: number;
}

/** 연산량을 억제하기 위해 분석 전 이미지를 축소할 최대 변 길이. */
const MAX_ANALYSIS_DIMENSION = 600;

/**
 * File(사진)을 브라우저에서 분석해 블러 여부를 판정한다.
 * 네트워크 요청 없이 로컬에서만 처리되며, 원본 파일은 이 함수 호출 후에도
 * 그대로 호출부가 들고 있는 File 객체일 뿐 별도로 저장되지 않는다.
 */
export async function checkPhotoBlur(
  file: File,
  threshold: number = DEFAULT_BLUR_VARIANCE_THRESHOLD,
): Promise<BlurCheckResult> {
  const bitmap = await createImageBitmap(file);
  try {
    const scale = Math.min(1, MAX_ANALYSIS_DIMENSION / Math.max(bitmap.width, bitmap.height));
    const width = Math.max(3, Math.round(bitmap.width * scale));
    const height = Math.max(3, Math.round(bitmap.height * scale));

    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) {
      throw new Error("2D 캔버스 컨텍스트를 사용할 수 없습니다.");
    }
    ctx.drawImage(bitmap, 0, 0, width, height);

    const imageData = ctx.getImageData(0, 0, width, height);
    const variance = laplacianVariance(imageData);

    return { isBlurry: isBlurryVariance(variance, threshold), variance, threshold };
  } finally {
    bitmap.close();
  }
}
