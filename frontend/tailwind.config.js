/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // 디자인팀 Figma 스크린샷에서 눈대중으로 추출한 근사값.
        // 정확한 hex는 Figma Dev Mode에서 받으면 이 팔레트만 교체하면 됨.
        brand: {
          50: "#EAFBF3",
          100: "#D3F5E6",
          300: "#8FE0BA",
          400: "#2FCB8F",
          500: "#1FB07A",
          600: "#15966A",
        },
      },
    },
  },
  plugins: [],
};
