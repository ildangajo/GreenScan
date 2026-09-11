import { describe, expect, it } from "vitest";
import { isBlurryVariance, laplacianVariance, toGrayscale, type GrayscaleSource } from "./blurDetection";

function makeFlatImage(width: number, height: number, gray: number): GrayscaleSource {
  const data = new Uint8ClampedArray(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    data[i * 4] = gray;
    data[i * 4 + 1] = gray;
    data[i * 4 + 2] = gray;
    data[i * 4 + 3] = 255;
  }
  return { data, width, height };
}

function makeCheckerboardImage(width: number, height: number): GrayscaleSource {
  const data = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = y * width + x;
      const value = (x + y) % 2 === 0 ? 0 : 255;
      data[i * 4] = value;
      data[i * 4 + 1] = value;
      data[i * 4 + 2] = value;
      data[i * 4 + 3] = 255;
    }
  }
  return { data, width, height };
}

describe("toGrayscale", () => {
  it("converts RGBA pixels using standard luma weights", () => {
    const data = new Uint8ClampedArray([255, 0, 0, 255, 0, 255, 0, 255]);
    const gray = toGrayscale({ data, width: 2, height: 1 });
    expect(gray[0]).toBeCloseTo(0.299 * 255, 1);
    expect(gray[1]).toBeCloseTo(0.587 * 255, 1);
  });
});

describe("laplacianVariance", () => {
  it("returns ~0 for a completely flat (uniform) image", () => {
    const flat = makeFlatImage(10, 10, 128);
    expect(laplacianVariance(flat)).toBeCloseTo(0, 5);
  });

  it("returns a large value for a high-contrast checkerboard image", () => {
    const checkerboard = makeCheckerboardImage(10, 10);
    const flat = makeFlatImage(10, 10, 128);
    expect(laplacianVariance(checkerboard)).toBeGreaterThan(laplacianVariance(flat));
  });

  it("throws for images smaller than 3x3", () => {
    const tiny = makeFlatImage(2, 2, 100);
    expect(() => laplacianVariance(tiny)).toThrow();
  });
});

describe("isBlurryVariance", () => {
  it("treats variance below the threshold as blurry", () => {
    expect(isBlurryVariance(10, 100)).toBe(true);
  });

  it("treats variance at or above the threshold as not blurry", () => {
    expect(isBlurryVariance(150, 100)).toBe(false);
  });
});
