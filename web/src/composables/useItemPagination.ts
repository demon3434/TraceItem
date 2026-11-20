import { ref } from "vue";
import type { Item } from "@/types";
import { getItemsApi, searchItemsApi } from "@/api";

export interface ItemFilterParams {
  houseId?: number | null;
  roomId?: number | null;
  categoryId?: number | null;
  searchQuery?: string;
}

/**
 * Web 端物品清单触底增量分页与防竞态状态管理
 */
export function useItemPagination(pageSize = 60) {
  const items = ref<Item[]>([]);
  const loading = ref(false);
  const loadingMore = ref(false);
  const loadMoreError = ref(false);
  const hasMore = ref(false);
  const total = ref(0);
  const currentPage = ref(1);

  let requestEpoch = 0;

  async function loadFirstPage(
    params: ItemFilterParams,
    onError?: (msg: string) => void
  ) {
    const epoch = ++requestEpoch;
    loading.value = true;
    loadingMore.value = false;
    loadMoreError.value = false;
    currentPage.value = 1;

    try {
      const q = params.searchQuery?.trim() ?? "";
      if (q.length > 0) {
        const res = await searchItemsApi(q);
        if (epoch !== requestEpoch) return;
        const filtered =
          params.categoryId != null
            ? res.filter((it) => it.category_id === params.categoryId)
            : res;
        items.value = filtered;
        total.value = filtered.length;
        hasMore.value = false;
      } else {
        const res = await getItemsApi({
          house_id: params.houseId || undefined,
          room_id: params.roomId || undefined,
          category_id: params.categoryId ?? undefined,
          page: 1,
          page_size: pageSize,
        });
        if (epoch !== requestEpoch) return;
        items.value = res.items;
        total.value = res.pagination?.total ?? res.items.length;
        hasMore.value = items.value.length < total.value;
      }
    } catch (err: any) {
      if (epoch !== requestEpoch) return;
      onError?.(err?.message || "网络异常");
    } finally {
      if (epoch === requestEpoch) {
        loading.value = false;
      }
    }
  }

  async function loadNextPage(
    params: ItemFilterParams,
    onError?: (msg: string) => void
  ) {
    if (
      loading.value ||
      loadingMore.value ||
      !hasMore.value ||
      (params.searchQuery?.trim() ?? "").length > 0
    ) {
      return;
    }

    const epoch = requestEpoch;
    const nextPage = currentPage.value + 1;
    loadingMore.value = true;
    loadMoreError.value = false;

    try {
      const res = await getItemsApi({
        house_id: params.houseId || undefined,
        room_id: params.roomId || undefined,
        category_id: params.categoryId ?? undefined,
        page: nextPage,
        page_size: pageSize,
      });
      if (epoch !== requestEpoch) return;

      if (res.items.length === 0) {
        hasMore.value = false;
      } else {
        currentPage.value = nextPage;
        items.value = [...items.value, ...res.items];
        total.value = res.pagination?.total ?? items.value.length;
        hasMore.value = items.value.length < total.value;
      }
    } catch (err: any) {
      if (epoch !== requestEpoch) return;
      loadMoreError.value = true;
      onError?.(err?.message || "加载更多失败");
    } finally {
      if (epoch === requestEpoch) {
        loadingMore.value = false;
      }
    }
  }

  return {
    items,
    loading,
    loadingMore,
    loadMoreError,
    hasMore,
    total,
    loadFirstPage,
    loadNextPage,
  };
}

