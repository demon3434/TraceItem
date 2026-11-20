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
            <div class="w-9 h-9 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center">
              <KeyRound class="w-5 h-5" />
            </div>
            <div>
              <h3 class="text-base font-bold text-slate-800">修改登录密码</h3>
              <p class="text-xs text-slate-500 mt-0.5">修改后所有端登录态将立即失效，需重新登录</p>
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
            <label class="block text-sm font-semibold text-slate-700 mb-1.5">新密码</label>
            <input
              v-model="newPassword"
              type="password"
              required
              minlength="6"
              placeholder="请输入至少 6 位的新密码"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-amber-400 bg-slate-50"
            />
          </div>

          <div>
            <label class="block text-sm font-semibold text-slate-700 mb-1.5">确认新密码</label>
            <input
              v-model="confirmPassword"
              type="password"
              required
              minlength="6"
              placeholder="请再次输入新密码"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-amber-400 bg-slate-50"
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
              class="px-5 py-2 text-sm font-bold text-white bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 rounded-xl shadow-xs transition-all disabled:opacity-60"
            >
              {{ submitting ? "提交中..." : "保存并重新登录" }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import { KeyRound, X } from "lucide-vue-next";
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

const newPassword = ref("");
const confirmPassword = ref("");
const submitting = ref(false);

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      newPassword.value = "";
      confirmPassword.value = "";
    }
  }
);

async function handleSubmit() {
  if (newPassword.value.length < 6) {
    toastStore.error("新密码长度不能少于 6 位");
    return;
  }
  if (newPassword.value !== confirmPassword.value) {
    toastStore.error("两次输入的新密码不一致，请核对");
    return;
  }
  submitting.value = true;
  try {
    await updateMeApi({ password: newPassword.value });
    toastStore.success("密码修改成功，请重新登录");
    emit("close");
    authStore.logout();
  } catch (err: any) {
    toastStore.error("修改密码失败", err.message);
  } finally {
    submitting.value = false;
  }
}
</script>

