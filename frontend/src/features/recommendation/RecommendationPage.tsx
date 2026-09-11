import { useNavigate } from "react-router-dom";
import BottomNav from "../../components/ui/BottomNav";
import chevronLeftIcon from "../ai-diagnosis/assets/chevron-left.svg";
import news1 from "./assets/news-1.png";
import news2 from "./assets/news-2.png";
import news3 from "./assets/news-3.jpg";

/**
 * 하단 탭바 "추천" 화면 — 그린리모델링 관련 외부 블로그 글 카드 목록.
 * 이미지를 누르면 원문 블로그 글이 새 탭으로 열린다.
 *
 * 주의:
 * - 카드 이미지는 각 블로그 글의 og:image를 그대로 받아온 것이다(실제 글쓴이
 *   콘텐츠). 자체 제작 배너가 아니라 외부 콘텐츠 링크라서 각 카드 하단에
 *   출처 표기를 남겨뒀다.
 * - 지금은 3개를 로컬 배열에 하드코딩했다. 실제로는 어드민이 등록한 추천
 *   콘텐츠 목록 API로 교체될 자리다.
 */

interface NewsItem {
  id: string;
  title: string;
  url: string;
  image: string;
}

const NEWS_ITEMS: NewsItem[] = [
  {
    id: "1",
    title: "전북 그린리모델링 시작! 군산 익산 전주 창호 교체 KCC창호",
    url: "https://blog.naver.com/roen_architecture/224207707955",
    image: news1,
  },
  {
    id: "2",
    title: "2026 한샘 그린리모델링 지원 사업 ㅣ오래 된 창호 고민이라면?",
    url: "https://blog.naver.com/nkdljy135/224362654859",
    image: news2,
  },
  {
    id: "3",
    title: "그린리모델링 이자지원 22일부터 신청 접수 안 하면 후회할 세부 혜택",
    url: "https://blog.naver.com/mercy1209/224292728652",
    image: news3,
  },
];

export default function RecommendationPage() {
  const navigate = useNavigate();

  return (
    <div className="relative mx-auto flex h-screen w-full max-w-md flex-col overflow-hidden bg-white">
      {/* 상단 헤더 — 뒤로가기 + 제목(와이어프레임 그대로 "홈") */}
      <header className="flex shrink-0 items-center gap-[21px] px-[21px] pb-3 pt-5">
        <button type="button" onClick={() => navigate(-1)} aria-label="뒤로가기" className="shrink-0">
          <img src={chevronLeftIcon} alt="" className="h-6 w-6" />
        </button>
        <h1 className="text-[18px] font-normal text-[#535353]">홈</h1>
      </header>

      <main className="min-h-0 flex-1 overflow-y-auto px-4 pb-8">
        {/* TODO: 실제 상단 광고/캠페인 배너 콘텐츠가 정해지면 이 자리에 채운다 */}
        <div className="h-20 rounded-2xl bg-brand-100" aria-hidden />

        <div className="mt-4 flex flex-col gap-4">
          {NEWS_ITEMS.map((item) => (
            <a
              key={item.id}
              href={item.url}
              target="_blank"
              rel="noopener noreferrer"
              className="block overflow-hidden rounded-2xl shadow-[0px_2px_8px_0px_rgba(0,0,0,0.1)]"
            >
              <img
                src={item.image}
                alt={item.title}
                className="block h-48 w-full object-cover"
              />
              <div className="flex items-center justify-between gap-2 bg-white px-4 py-3">
                <p className="line-clamp-2 text-sm font-semibold text-neutral-800">{item.title}</p>
                <span className="shrink-0 text-xs text-neutral-400">네이버 블로그</span>
              </div>
            </a>
          ))}
        </div>
      </main>

      <BottomNav active="news" />
    </div>
  );
}
