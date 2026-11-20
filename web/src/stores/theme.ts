import { defineStore } from "pinia";
import { ref } from "vue";
import sharedThemes from "@shared/themes.json";

export interface ThemeConfig {
  id: string;
  name: string;
  icon: string;
  category: "dopamine" | "shadcn";
  primaryColor: string;
  gradient: string;
  desc: string;
}

export const THEMES: ThemeConfig[] = [
  ...sharedThemes.dopamine.map((t) => ({
    id: t.id,
    name: t.name,
    icon: t.icon,
    category: "dopamine" as const,
    primaryColor: t.primary.toLowerCase(),
    gradient: t.gradient,
    desc: t.desc,
  })),
  ...sharedThemes.shadcn.map((t) => ({
    id: t.id,
    name: t.name,
    icon: t.icon,
    category: "shadcn" as const,
    primaryColor: t.primary.toLowerCase(),
    gradient: t.gradient,
    desc: t.desc,
  })),
];

export const useThemeStore = defineStore("theme", () => {
  const currentThemeId = ref<string>(
    localStorage.getItem("traceitem_theme") || "warm-orange"
  );

  const currentTheme = ref<ThemeConfig>(
    THEMES.find((t) => t.id === currentThemeId.value) || THEMES[0]
  );

  function applyTheme(themeId: string) {
    const target = THEMES.find((t) => t.id === themeId) || THEMES[0];
    currentThemeId.value = target.id;
    currentTheme.value = target;
    localStorage.setItem("traceitem_theme", target.id);
    document.documentElement.setAttribute("data-theme", target.id);
  }

  // 初始化应用主题
  applyTheme(currentThemeId.value);

  return {
    themes: THEMES,
    currentThemeId,
    currentTheme,
    applyTheme,
  };
});
