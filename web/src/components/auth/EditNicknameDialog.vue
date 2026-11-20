<template>
  <Transition
    enter-active-class="ease-out duration-200 transition"
    enter-from-class="opacity-0 scale-95"
    enter-to-class="opacity-100 scale-100"
    leave-active-class="ease-in duration-150 transition"
    leave-from-class="opacity-100 scale-100"
    leave-to-class="opacity-0 scale-95"
  >
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm"
      @click.self="emit('close')"
    >
      <div class="w-full max-w-md bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100">
        <!-- 头部 -->
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <div class="flex items-center space-x-2.5">
            <div class="w-9 h-9 rounded-xl bg-sky-100 text-sky-600 flex items-center justify-center">
              <Pencil class="w-5 h-5" />
            </div>
            <div>
              <h3 class="text-base font-bold text-slate-800">修改显示昵称</h3>
              <p class="text-xs text-slate-500 mt-0.5">更新当前账号在家庭空间中的称呼</p>
            </div>
          </div>
          <button
            type="button"
            @click="emit('close')"
            class="text-slate-400 hover:text-slate-600 p-1 rounded-lg"
            aria-label="关闭弹窗"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- 表单 -->
        <form @submit.prevent="handleSubmit" class="mt-4 space-y-4">
          <div>
            <label class="block text-sm font-semibold text-slate-700 mb-1.5">新昵称</label>
            <input
              v-model="nickname"
              type="text"
              required
              maxlength="30"
              placeholder="请输入新的显示昵称"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-sky-400 bg-slate-50"
            />
          </div>

          <div class="flex items-center justify-end space-x-3 pt-3 border-t border-slate-100">
            <button
              type="button"
              @click="emit('close')"
              class="px-4 py-2 text-sm font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
            >
              取消
            </button>
            <button
              type="submit"
              :disabled="submitting"
              class="btn-theme-primary px-5 py-2 text-sm font-bold rounded-xl shadow-xs transition-all disabled:opacity-60"
            >
              {{ submitting ? "保存中..." : "保存昵称" }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import { Pencil, X } from "lucide-vue-next";
import { updateMeApi } from "@/api";
import { useAuthStore } from "@/stores/auth";
import { useToastStore } from "@/stores/toast";

const props = defineProps<{
  isOpen: boolean;
}>();

const emit = defineEmits<{
  close: [];
}>();

const authStore = useAuthStore();
const toastStore = useToastStore();

const nickname = ref("");
const submitting = ref(false);

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      nickname.value = authStore.user?.nickname || "";
    }
  }
);

async function handleSubmit() {
  const trimmed = nickname.value.trim();
  if (!trimmed) {
    toastStore.error("昵称不能为空");
    return;
  }
  submitting.value = true;
  try {
    const updatedUser = await updateMeApi({ nickname: trimmed });
    authStore.updateUser(updatedUser);
    toastStore.success("昵称修改成功");
    emit("close");
  } catch (err: any) {
    toastStore.error("修改昵称失败", err.message);
  } finally {
    submitting.value = false;
  }
}
</script>

