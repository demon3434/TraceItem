<template>
  <div class="min-h-screen flex items-center justify-center p-4 bg-gradient-to-br from-orange-50 via-amber-50/40 to-white">
    <div class="w-full max-w-md bg-white rounded-squircle-lg p-8 shadow-xl border border-orange-100/60">
      <!-- 头部 Logo -->
      <div class="text-center mb-6">
        <img
          src="/logo.png"
          alt="图觅"
          class="w-16 h-16 rounded-3xl mx-auto shadow-lg shadow-orange-200/50 mb-3.5 object-cover"
        />
        <h1 class="text-2xl font-black text-slate-800 tracking-tight">图觅</h1>
      </div>

      <!-- 登录 / 注册 Tab 切换 (受公开注册开关保护) -->
      <div v-if="allowPublicRegistration" class="flex items-center p-1 bg-slate-100 rounded-2xl mb-6">
        <button
          type="button"
          @click="activeTab = 'login'"
          class="flex-1 py-2 text-sm font-bold rounded-xl transition-all"
          :class="activeTab === 'login' ? 'bg-white text-orange-600 shadow-xs' : 'text-slate-500 hover:text-slate-800'"
        >
          账号登录
        </button>
        <button
          type="button"
          @click="activeTab = 'register'"
          class="flex-1 py-2 text-sm font-bold rounded-xl transition-all"
          :class="activeTab === 'register' ? 'bg-white text-orange-600 shadow-xs' : 'text-slate-500 hover:text-slate-800'"
        >
          注册新账号
        </button>
      </div>

      <!-- 快速体验切换胶囊 (仅在登录模式下展示) -->
      <div v-if="activeTab === 'login' && quickAccounts.length > 0" class="mb-6 p-3 bg-amber-50/60 rounded-2xl border border-amber-100">
        <p class="text-xs font-bold text-amber-800 uppercase tracking-wider mb-2 text-center">
          🛠️ 快速切换账号
        </p>
        <div class="grid grid-cols-3 gap-2">
          <button
            v-for="acc in quickAccounts"
            :key="acc.u"
            type="button"
            @click="quickFill(acc.u, acc.p)"
            class="p-2 rounded-xl border bg-white hover:bg-orange-50 text-xs font-semibold text-slate-800 transition-colors flex flex-col items-center"
            :class="acc.border"
          >
            <span>{{ acc.name }}</span>
            <span class="text-xs font-medium" :class="acc.text">{{ acc.desc }}</span>
          </button>
        </div>
      </div>

      <!-- A. 登录表单 -->
      <form v-if="activeTab === 'login'" @submit.prevent="handleLogin" class="space-y-4">
        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">登录账号</label>
          <input
            v-model="username"
            type="text"
            required
            placeholder="请输入账号"
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50"
          />
        </div>

        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">登录密码</label>
          <input
            v-model="password"
            type="password"
            required
            placeholder="请输入密码"
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50"
          />
        </div>

        <button
          type="submit"
          :disabled="loading"
          class="w-full py-3 bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white font-bold text-sm rounded-xl shadow-lg shadow-orange-200 transition-all hover:scale-[1.01] disabled:opacity-50"
        >
          {{ loading ? "正在进入空间..." : "进入空间账本" }}
        </button>
      </form>

      <!-- B. 注册表单 -->
      <form v-else @submit.prevent="handleRegister" class="space-y-4">
        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">登录账号</label>
          <input
            v-model="regUsername"
            type="text"
            required
            placeholder="请输入账号（字母或数字）"
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50"
          />
        </div>

        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">用户昵称</label>
          <input
            v-model="regNickname"
            type="text"
            required
            placeholder="请输入您的昵称（系统界面优先显示此昵称）"
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50"
          />
        </div>

        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">登录密码</label>
          <input
            v-model="regPassword"
            type="password"
            required
            placeholder="请输入至少 6 位密码"
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50"
          />
        </div>

        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">确认密码</label>
          <input
            v-model="regConfirmPassword"
            type="password"
            required
            placeholder="请再次输入登录密码"
            class="w-full px-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50"
          />
        </div>

        <button
          type="submit"
          :disabled="loading"
          class="w-full py-3 bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white font-bold text-sm rounded-xl shadow-lg shadow-orange-200 transition-all hover:scale-[1.01] disabled:opacity-50"
        >
          {{ loading ? "正在创建账号..." : "立即注册并进入空间" }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { getAuthConfigApi, loginApi, registerApi } from "@/api";
import { useAuthStore } from "@/stores/auth";
import { useToastStore } from "@/stores/toast";
import { Compass } from "lucide-vue-next";

const router = useRouter();
const authStore = useAuthStore();
const toastStore = useToastStore();

const activeTab = ref<"login" | "register">("login");
const allowPublicRegistration = ref(true);

const isDev = import.meta.env.DEV;

const quickAccounts = isDev
  ? [
      { name: "👑 系统管理员", desc: "上帝视角/TAR", u: "admin", p: "admin123", border: "border-purple-200", text: "text-purple-600" },
      { name: "👩 爱丽丝", desc: "私有空间账本", u: "alice", p: "123456", border: "border-orange-200", text: "text-orange-600" },
      { name: "👨 鲍勃", desc: "私有空间账本", u: "bob", p: "123456", border: "border-blue-200", text: "text-blue-600" },
    ]
  : [];

const username = ref(isDev ? (quickAccounts[0]?.u || "") : "");
const password = ref(isDev ? (quickAccounts[0]?.p || "") : "");
const regUsername = ref("");
const regNickname = ref("");
const regPassword = ref("");
const regConfirmPassword = ref("");
const loading = ref(false);

onMounted(async () => {
  try {
    const cfg = await getAuthConfigApi();
    allowPublicRegistration.value = cfg.allow_public_registration;
    if (!cfg.allow_public_registration && activeTab.value === "register") {
      activeTab.value = "login";
    }
  } catch {
    // 忽略加载错误，保持默认
  }
});

function quickFill(u: string, p: string) {
  username.value = u;
  password.value = p;
}

async function handleLogin() {
  if (!username.value || !password.value) return;
  loading.value = true;
  try {
    const res = await loginApi({ username: username.value, password: password.value });
    authStore.setAuth(res.access_token, res.user);
    toastStore.success(`欢迎回来，${res.user.nickname || res.user.username}！`, "已载入您的专属独立私有空间");
    router.push("/");
  } catch (err: any) {
    toastStore.error("登录失败", err.message || "用户名或密码错误");
  } finally {
    loading.value = false;
  }
}

async function handleRegister() {
  if (!regUsername.value.trim() || !regPassword.value || !regNickname.value.trim()) {
    toastStore.warning("请完整填写注册信息", "账号、密码和昵称均为必填项");
    return;
  }
  if (regPassword.value !== regConfirmPassword.value) {
    toastStore.warning("两次输入的密码不一致", "请重新核对登录密码");
    return;
  }
  loading.value = true;
  try {
    // 1. 注册新账号
    await registerApi({
      username: regUsername.value.trim(),
      password: regPassword.value,
      nickname: regNickname.value.trim(),
    });

    // 2. 自动执行登录，无缝进入空间
    const loginRes = await loginApi({
      username: regUsername.value.trim(),
      password: regPassword.value,
    });
    authStore.setAuth(loginRes.access_token, loginRes.user);
    toastStore.success(`注册成功！欢迎您，${loginRes.user.nickname}`, "已自动为您预置收纳分类模板");
    router.push("/");
  } catch (err: any) {
    toastStore.error("注册失败", err.message || "该账号可能已被注册");
  } finally {
    loading.value = false;
  }
}
</script>
