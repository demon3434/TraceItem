<template>
  <div class="space-y-6">
    <!-- 顶栏：标题与开户操作 -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-5 rounded-3xl border border-slate-100 shadow-2xs">
      <div>
        <div class="flex items-center space-x-2.5">
          <div class="w-10 h-10 rounded-2xl bg-amber-100 text-amber-700 flex items-center justify-center font-bold">
            <Users class="w-5 h-5" />
          </div>
          <div>
            <h3 class="text-lg font-black text-slate-800">用户账号管理</h3>
            <p class="text-xs text-slate-400 mt-0.5">管控系统用户独立账本、分配账号、重置密码与安全冻结</p>
          </div>
        </div>
      </div>

      <!-- 中部系统概览指标胶囊 (自全局顶栏下移至面板小标题栏) -->
      <div v-if="adminStats" class="hidden xl:flex items-center space-x-2 text-xs font-bold text-slate-600">
        <div class="px-3 py-1.5 rounded-full bg-slate-100 flex items-center space-x-1.5 shadow-2xs" title="当前全系统注册用户">
          <span>👥</span>
          <span>{{ adminStats.total_users ?? 0 }} 人</span>
        </div>
        <div class="px-3 py-1.5 rounded-full bg-amber-50 text-amber-800 border border-amber-200/60 flex items-center space-x-1.5 shadow-2xs" title="全库收纳物品总数">
          <span>📦</span>
          <span>{{ adminStats.total_items ?? 0 }} 件</span>
        </div>
        <div class="px-3 py-1.5 rounded-full bg-emerald-50 text-emerald-800 border border-emerald-200/60 flex items-center space-x-1.5 shadow-2xs" title="多媒体物理磁盘占用">
          <span>💾</span>
          <span>{{ adminStats.media_storage_display || '0 KB' }}</span>
        </div>
        <div class="px-3 py-1.5 rounded-full bg-orange-50 text-orange-800 border border-orange-200/60 flex items-center space-x-1.5 shadow-2xs" title="最新备份时间">
          <span>🛡️</span>
          <span>{{ adminStats.last_backup_time ? formatBackupTime(adminStats.last_backup_time) : '无备份' }}</span>
        </div>
      </div>

      <div class="flex items-center space-x-3">
        <button
          @click="loadUsers"
          :disabled="loading"
          class="p-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors"
          title="刷新用户列表"
        >
          <RefreshCw class="w-4 h-4" :class="{ 'animate-spin': loading }" />
        </button>
        <button
          @click="openCreateDialog"
          class="px-4 py-2.5 bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white text-sm font-bold rounded-xl shadow-sm transition-all hover:scale-[1.02] flex items-center space-x-2"
        >
          <UserPlus class="w-4 h-4" />
          <span>+ 添加新用户</span>
        </button>
      </div>
    </div>

    <!-- 成员卡片网格 -->
    <div v-if="loading && users.length === 0" class="text-center py-16 text-slate-400 text-sm">
      正在加载家庭成员账本概况...
    </div>

    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      <div
        v-for="u in users"
        :key="u.id"
        class="bg-white p-5 rounded-3xl border transition-all flex flex-col justify-between shadow-2xs hover:shadow-sm"
        :class="u.is_active ? 'border-slate-100 hover:border-amber-200' : 'border-rose-100 bg-rose-50/20'"
      >
        <div>
          <!-- 卡片顶栏：头像与状态 -->
          <div class="flex items-start justify-between">
            <div class="flex items-center space-x-3.5">
              <div
                class="w-12 h-12 rounded-2xl flex items-center justify-center text-lg font-black shadow-xs flex-shrink-0"
                :class="
                  u.role === 'admin'
                    ? 'bg-gradient-to-tr from-amber-500 to-orange-400 text-white'
                    : 'bg-orange-100 text-orange-700'
                "
              >
                {{ u.nickname?.charAt(0) || u.username.charAt(0).toUpperCase() }}
              </div>
              <div class="min-w-0">
                <div class="flex items-center space-x-2">
                  <h4 class="text-base font-bold text-slate-800 truncate">{{ u.nickname || u.username }}</h4>
                  <span
                    v-if="u.role === 'admin'"
                    class="px-2 py-0.5 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-200"
                  >
                    👑 系统管理员
                  </span>
                </div>
                <p class="text-xs text-slate-400 mt-1">@{{ u.username }} · 注册于 {{ formatDate(u.created_at) }}</p>
              </div>
            </div>

            <!-- 状态标签 -->
            <span
              class="px-2.5 py-1 rounded-xl text-xs font-bold flex items-center space-x-1"
              :class="
                u.is_active
                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-100'
                  : 'bg-rose-50 text-rose-700 border border-rose-100'
              "
            >
              <span class="w-1.5 h-1.5 rounded-full" :class="u.is_active ? 'bg-emerald-500' : 'bg-rose-500'"></span>
              <span>{{ u.is_active ? "正常活跃" : "已冻结" }}</span>
            </span>
          </div>

          <!-- 资产统计概览 (房屋、房间、物品) -->
          <div class="mt-4 p-3 bg-slate-50/80 rounded-2xl grid grid-cols-3 gap-2 text-center border border-slate-100/80">
            <div>
              <p class="text-xs text-slate-400 font-medium">房屋</p>
              <p class="text-sm font-bold text-slate-800 mt-0.5">{{ u.house_count }}</p>
            </div>
            <div class="border-x border-slate-200/60">
              <p class="text-xs text-slate-400 font-medium">房间</p>
              <p class="text-sm font-bold text-slate-800 mt-0.5">{{ u.room_count }}</p>
            </div>
            <div>
              <p class="text-xs text-slate-400 font-medium">物品收纳</p>
              <p class="text-sm font-bold text-amber-600 mt-0.5">{{ u.item_count }} 件</p>
            </div>
          </div>
        </div>

        <!-- 底部管理动作 -->
        <div class="mt-5 pt-3 border-t border-slate-100 flex items-center justify-end space-x-2">
          <!-- 初始化密码为默认 123456 -->
          <button
            @click="confirmInitPassword(u)"
            class="px-2.5 py-1.5 text-xs font-semibold text-slate-600 hover:text-amber-700 bg-slate-100 hover:bg-amber-50 rounded-xl transition-colors flex items-center space-x-1"
            title="一键初始化恢复默认密码 123456"
          >
            <RotateCcw class="w-3.5 h-3.5" />
            <span>初始密码</span>
          </button>

          <!-- 自定义重置密码 -->
          <button
            @click="openResetPasswordDialog(u)"
            class="px-2.5 py-1.5 text-xs font-semibold text-slate-600 hover:text-amber-700 bg-slate-100 hover:bg-amber-50 rounded-xl transition-colors flex items-center space-x-1"
          >
            <KeyRound class="w-3.5 h-3.5" />
            <span>改密码</span>
          </button>

          <!-- 冻结 / 恢复 (排除当前登录管理员自身) -->
          <button
            v-if="u.id !== authStore.user?.id"
            @click="toggleUserStatusConfirm(u)"
            class="px-3 py-1.5 text-xs font-semibold rounded-xl transition-colors flex items-center space-x-1"
            :class="
              u.is_active
                ? 'text-rose-600 bg-rose-50 hover:bg-rose-100'
                : 'text-emerald-700 bg-emerald-50 hover:bg-emerald-100'
            "
          >
            <ShieldAlert v-if="u.is_active" class="w-3.5 h-3.5" />
            <ShieldCheck v-else class="w-3.5 h-3.5" />
            <span>{{ u.is_active ? "冻结账号" : "解除冻结" }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- 1. 新建成员弹窗 (统一温润大圆角) -->
    <Transition enter-active-class="ease-out duration-200" enter-from-class="opacity-0 scale-95" enter-to-class="opacity-100 scale-100">
      <div v-if="showCreateDialog" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm" @click.self="showCreateDialog = false">
        <div class="w-full max-w-md bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100">
          <div class="flex items-center justify-between pb-3 border-b border-slate-100">
            <h3 class="text-base font-bold text-slate-800 flex items-center space-x-2">
              <UserPlus class="w-5 h-5 text-amber-500" />
              <span>添加系统用户</span>
            </h3>
            <button @click="showCreateDialog = false" class="text-slate-400 hover:text-slate-600 p-1 rounded-lg">
              <X class="w-5 h-5" />
            </button>
          </div>

          <form @submit.prevent="handleCreateUser" class="mt-4 space-y-4">
            <div>
              <label class="block text-xs font-bold text-slate-700 mb-1">登录账号 (唯一用户名)</label>
              <input
                v-model="createForm.username"
                type="text"
                required
                placeholder="例如：grandpa, lily"
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-amber-400 bg-slate-50"
              />
            </div>

            <div>
              <label class="block text-xs font-bold text-slate-700 mb-1">用户昵称</label>
              <input
                v-model="createForm.nickname"
                type="text"
                required
                placeholder="例如：爷爷、小宝"
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-amber-400 bg-slate-50"
              />
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-bold text-slate-700">登录初始密码 (选填)</label>
                <span class="text-xs text-amber-600 font-semibold">留空默认 123456</span>
              </div>
              <input
                v-model="createForm.password"
                type="password"
                placeholder="留空自动使用默认密码 123456"
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-amber-400 bg-slate-50"
              />
            </div>

            <div class="pt-3 border-t border-slate-100 flex justify-end space-x-2">
              <button
                type="button"
                @click="showCreateDialog = false"
                class="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                取消
              </button>
              <button
                type="submit"
                :disabled="submitting"
                class="px-5 py-2 text-xs font-bold text-white bg-amber-500 hover:bg-amber-600 rounded-xl shadow-xs"
              >
                {{ submitting ? "创建中..." : "确认添加" }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Transition>

    <!-- 2. 重置密码弹窗 -->
    <Transition enter-active-class="ease-out duration-200" enter-from-class="opacity-0 scale-95" enter-to-class="opacity-100 scale-100">
      <div v-if="showResetModal" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm" @click.self="showResetModal = false">
        <div class="w-full max-w-sm bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100">
          <div class="flex items-center justify-between pb-3 border-b border-slate-100">
            <h3 class="text-base font-bold text-slate-800 flex items-center space-x-2">
              <KeyRound class="w-5 h-5 text-amber-500" />
              <span>重置成员密码</span>
            </h3>
            <button @click="showResetModal = false" class="text-slate-400 hover:text-slate-600 p-1 rounded-lg">
              <X class="w-5 h-5" />
            </button>
          </div>

          <div class="mt-4 space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-xs text-slate-600">
                正在为 <strong class="text-slate-800">{{ targetUser?.nickname || targetUser?.username }}</strong> 重置密码：
              </p>
              <button
                type="button"
                @click="newPassword = '123456'"
                class="text-xs text-amber-600 hover:text-amber-700 font-bold underline"
              >
                填入默认密码 123456
              </button>
            </div>
            <input
              v-model="newPassword"
              type="password"
              placeholder="输入新密码 (至少 6 位)"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-amber-400 bg-slate-50"
            />
          </div>

          <div class="mt-5 pt-3 border-t border-slate-100 flex justify-end space-x-2">
            <button
              type="button"
              @click="showResetModal = false"
              class="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl"
            >
              取消
            </button>
            <button
              type="button"
              @click="handleResetPassword"
              :disabled="submitting || !newPassword"
              class="px-5 py-2 text-xs font-bold text-white bg-amber-500 hover:bg-amber-600 rounded-xl shadow-xs disabled:opacity-50"
            >
              {{ submitting ? "提交中..." : "确认重置" }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- 3. 冻结 / 解冻确认弹窗 (无原生 confirm) -->
    <ConfirmDialog
      :is-open="showStatusConfirm"
      :title="targetUser?.is_active ? '确认冻结该成员账号？' : '确认解除该账号冻结？'"
      :message="targetUser?.is_active ? `冻结后用户【${targetUser?.nickname}】将无法继续登录空间，已有数据将完好保留。` : `恢复后用户【${targetUser?.nickname}】可正常登录其私有空间。`"
      :is-danger="targetUser?.is_active"
      :confirm-text="targetUser?.is_active ? '确认冻结' : '恢复激活'"
      @confirm="executeToggleStatus"
      @cancel="showStatusConfirm = false"
    />

    <!-- 4. 初始化默认密码确认弹窗 (无原生 confirm) -->
    <ConfirmDialog
      :is-open="showInitPasswordConfirm"
      title="确认初始化该成员密码？"
      :message="`将成员【${targetUser?.nickname || targetUser?.username}】的密码重置为系统默认密码【123456】。`"
      :is-danger="false"
      confirm-text="确认重置为 123456"
      @confirm="executeInitPassword"
      @cancel="showInitPasswordConfirm = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import type { AdminUser, AdminSystemStats } from "@/types";
import {
  getAdminUsersApi,
  getAdminStatsApi,
  createAdminUserApi,
  updateAdminUserStatusApi,
  resetAdminUserPasswordApi,
  initAdminUserPasswordApi,
} from "@/api";
import { useAuthStore } from "@/stores/auth";
import { useToastStore } from "@/stores/toast";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";
import { Users, UserPlus, KeyRound, ShieldAlert, ShieldCheck, RefreshCw, RotateCcw, X } from "lucide-vue-next";

const authStore = useAuthStore();
const toastStore = useToastStore();

const users = ref<AdminUser[]>([]);
const adminStats = ref<AdminSystemStats | null>(null);
const loading = ref(false);
const submitting = ref(false);

const showCreateDialog = ref(false);
const createForm = ref({ username: "", nickname: "", password: "" });

const showResetModal = ref(false);
const targetUser = ref<AdminUser | null>(null);
const newPassword = ref("");

const showStatusConfirm = ref(false);
const showInitPasswordConfirm = ref(false);

onMounted(() => {
  loadUsers();
});

async function loadUsers() {
  loading.value = true;
  try {
    const [uList, st] = await Promise.all([
      getAdminUsersApi(),
      getAdminStatsApi().catch(() => null),
    ]);
    users.value = uList;
    if (st) adminStats.value = st;
  } catch (err: any) {
    toastStore.error("加载成员列表失败", err.message);
  } finally {
    loading.value = false;
  }
}

function formatBackupTime(iso: string) {
  if (!iso) return "无备份";
  const d = new Date(iso);
  return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

function formatDate(isoStr: string): string {
  if (!isoStr) return "";
  const d = new Date(isoStr);
  return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`;
}

function openCreateDialog() {
  createForm.value = { username: "", nickname: "", password: "" };
  showCreateDialog.value = true;
}

async function handleCreateUser() {
  if (!createForm.value.username.trim() || !createForm.value.nickname.trim()) {
    toastStore.warning("请填写账号与用户昵称");
    return;
  }
  submitting.value = true;
  try {
    const res = await createAdminUserApi({
      username: createForm.value.username.trim(),
      nickname: createForm.value.nickname.trim(),
      password: createForm.value.password.trim() || undefined,
    });
    toastStore.success(`成员【${res.nickname}】开户成功！`, "初始密码: " + (createForm.value.password.trim() || "123456"));
    showCreateDialog.value = false;
    await loadUsers();
  } catch (err: any) {
    toastStore.error("添加成员失败", err.message);
  } finally {
    submitting.value = false;
  }
}

function openResetPasswordDialog(u: AdminUser) {
  targetUser.value = u;
  newPassword.value = "";
  showResetModal.value = true;
}

async function handleResetPassword() {
  if (!targetUser.value || !newPassword.value) return;
  submitting.value = true;
  try {
    await resetAdminUserPasswordApi(targetUser.value.id, newPassword.value);
    toastStore.success(`用户【${targetUser.value.nickname}】密码重置成功！`);
    showResetModal.value = false;
  } catch (err: any) {
    toastStore.error("重置密码失败", err.message);
  } finally {
    submitting.value = false;
  }
}

function toggleUserStatusConfirm(u: AdminUser) {
  targetUser.value = u;
  showStatusConfirm.value = true;
}

async function executeToggleStatus() {
  if (!targetUser.value) return;
  try {
    const nextStatus = !targetUser.value.is_active;
    await updateAdminUserStatusApi(targetUser.value.id, nextStatus);
    toastStore.success(nextStatus ? "账号已恢复激活" : "账号已冻结");
    showStatusConfirm.value = false;
    await loadUsers();
  } catch (err: any) {
    toastStore.error("操作失败", err.message);
  }
}

function confirmInitPassword(u: AdminUser) {
  targetUser.value = u;
  showInitPasswordConfirm.value = true;
}

async function executeInitPassword() {
  if (!targetUser.value) return;
  try {
    await initAdminUserPasswordApi(targetUser.value.id);
    toastStore.success(`用户【${targetUser.value.nickname}】密码已初始化为 123456！`);
    showInitPasswordConfirm.value = false;
  } catch (err: any) {
    toastStore.error("初始化密码失败", err.message);
  }
}
</script>

