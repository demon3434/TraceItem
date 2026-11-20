<template>
  <Transition
    enter-active-class="ease-out duration-250 transition"
    enter-from-class="opacity-0"
    enter-to-class="opacity-100"
    leave-active-class="ease-in duration-200 transition"
    leave-from-class="opacity-100"
    leave-to-class="opacity-0"
  >
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm"
      @click.self="handleCancel"
    >
      <div
        class="w-full max-w-md bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 transform transition-all duration-300 scale-100"
      >
        <div class="flex items-center space-x-3 mb-4">
          <div
            class="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0"
            :class="isDanger ? 'bg-rose-50 text-rose-500' : 'bg-orange-50 text-orange-500'"
          >
            <AlertTriangle v-if="isDanger" class="w-6 h-6" />
            <HelpCircle v-else class="w-6 h-6" />
          </div>
          <div>
            <h3 class="text-lg font-bold text-slate-800">{{ title }}</h3>
            <p class="text-sm text-slate-500 mt-0.5">{{ message }}</p>
          </div>
        </div>

        <div class="flex items-center justify-end space-x-3 mt-6">
          <button
            type="button"
            class="px-4 py-2 text-sm font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
            @click="handleCancel"
          >
            {{ cancelText }}
          </button>
          <button
            type="button"
            class="px-5 py-2 text-sm font-medium text-white rounded-xl shadow-sm transition-all"
            :class="
              isDanger
                ? 'bg-rose-500 hover:bg-rose-600 shadow-rose-200'
                : 'bg-orange-500 hover:bg-orange-600 shadow-orange-200'
            "
            @click="handleConfirm"
          >
            {{ confirmText }}
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { AlertTriangle, HelpCircle } from "lucide-vue-next";

defineProps({
  isOpen: { type: Boolean, default: false },
  title: { type: String, default: "确认操作" },
  message: { type: String, default: "您确定要继续此操作吗？" },
  confirmText: { type: String, default: "确认" },
  cancelText: { type: String, default: "取消" },
  isDanger: { type: Boolean, default: false },
});

const emit = defineEmits(["confirm", "cancel"]);

function handleConfirm() {
  emit("confirm");
}

function handleCancel() {
  emit("cancel");
}
</script>

