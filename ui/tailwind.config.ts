import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        kpmg: {
          blue: "#00338D",
          "mid-blue": "#005EB8",
          "light-blue": "#0091DA",
          "pale-blue": "#E6F4FB",
          black: "#1E1E1E",
          gray: "#F4F5F7",
          "gray-mid": "#DEDEDE",
          "gray-dark": "#6B7280",
          white: "#FFFFFF",
          purple: "#470A68",
          teal: "#00A3A1",
        },
      },
      fontFamily: {
        sans: ["Open Sans", "system-ui", "sans-serif"],
      },
      boxShadow: {
        card: "0 1px 3px 0 rgba(0,0,0,0.08), 0 1px 2px 0 rgba(0,0,0,0.04)",
        "card-hover": "0 4px 12px 0 rgba(0,0,0,0.12)",
      },
    },
  },
  plugins: [],
};

export default config;
