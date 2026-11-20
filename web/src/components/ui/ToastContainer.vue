<template>
  <div class="fixed top-6 right-6 z-50 flex flex-col space-y-3 pointer-events-none max-w-sm w-full">
    <TransitionGroup
      enter-active-class="transform ease-out duration-300 transition"
      enter-from-class="translate-y-2 opacity-0 sm:translate-y-0 sm:translate-x-4"
      enter-to-class="translate-y-0 opacity-100 sm:translate-x-0"
      leave-active-class="transition ease-in duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-for="item in toastStore.toasts"
        :key="item.id"
        class="pointer-events-auto flex items-start p-4 rounded-squircle bg-white/95 backdrop-blur-md shadow-lg border border-slate-100/80"
        :class="{
          'border-l-4 border-l-emerald-500': item.type === 'success',
          'border-l-4 border-l-rose-500': item.type === 'error',
          'border-l-4 border-l-amber-500': item.type === 'warning',
          'border-l-4 border-l-sky-500': item.type === 'info',
        }"
      >
        <div class="flex-shrink-0 mr-3 mt-0.5">
          <CheckCircle2 v-if="item.type === 'success'" class="w-5 h-5 text-emerald-500" />
          <AlertCircle v-else-if="item.type === 'error'" class="w-5 h-5 text-rose-500" />
          <AlertTriangle v-else-if="item.type === 'warning'" class="w-5 h-5 text-amber-500" />
          <Info v-else class="w-5 h-5 text-sky-500" />
        </div>
        <div class="flex-1 min-w-0 pr-2">
          <p class="text-sm font-semibold text-slate-800 leading-tight">{{ item.title }}</p>
          <p v-if="item.message" class="text-xs text-slate-500 mt-1 leading-normal">{{ item.message }}</p>
        </div>
        <button
          @click="toastStore.remove(item.id)"
          class="flex-shrink-0 text-slate-400 hover:text-slate-600 transition-colors"
        >
          <X class="w-4 h-4" />
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>

<script setup lang="ts">
import { useToastStore } from "@/stores/toast";
import { CheckCircle2, AlertCircle, AlertTriangle, Info, X } from "lucide-vue-next";

const toastStore = useToastStore();
</script>

