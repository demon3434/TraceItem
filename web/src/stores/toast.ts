import { defineStore } from "pinia";
import { ref } from "vue";

export interface ToastItem {
  id: string;
  type: "success" | "error" | "info" | "warning";
  title: string;
  message?: string;
  duration?: number;
}

export const useToastStore = defineStore("toast", () => {
  const toasts = ref<ToastItem[]>([]);

  function show(toast: Omit<ToastItem, "id">) {
    const id = Math.random().toString(36).substring(2, 9);
    const item: ToastItem = {
      ...toast,
      id,
      duration: toast.duration ?? 3500,
    };
    toasts.value.push(item);

    if (item.duration > 0) {
      setTimeout(() => {
        remove(id);
      }, item.duration);
    }
  }

  function success(title: string, message?: string) {
    show({ type: "success", title, message });
  }

  function error(title: string, message?: string) {
    show({ type: "error", title, message, duration: 4500 });
  }

  function info(title: string, message?: string) {
    show({ type: "info", title, message });
  }

  function warning(title: string, message?: string) {
    show({ type: "warning", title, message });
  }

  function remove(id: string) {
    toasts.value = toasts.value.filter((t) => t.id !== id);
  }

  return { toasts, show, success, error, info, warning, remove };
});

