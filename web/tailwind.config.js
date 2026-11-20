/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "var(--theme-primary)",
          hover: "var(--theme-primary-hover)",
          light: "var(--theme-primary-light)",
          border: "var(--theme-primary-border)",
          text: "var(--theme-primary-text)",
        },
        dopamine: {
          orange: "#F97316",
          amber: "#F59E0B",
          strawberry: "#F43F5E",
          mint: "#10B981",
          lime: "#84CC16",
          sky: "#0EA5E9",
          lavender: "#8B5CF6",
          warmbg: "var(--theme-bg)",
        },
      },
      borderRadius: {
        'squircle-sm': '14px',
        'squircle': '20px',
        'squircle-lg': '28px',
      },
      boxShadow: {
        'soft': '0 8px 30px rgba(0, 0, 0, 0.05)',
        'soft-hover': '0 12px 35px var(--theme-shadow)',
        'theme': '0 4px 16px -2px var(--theme-shadow)',
      },
    },
  },
  plugins: [],
}
