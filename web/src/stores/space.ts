import { defineStore } from "pinia";
import { ref, computed } from "vue";
import type { House, Room } from "../types";
import { getHousesApi, getRoomsApi, reorderHousesApi, reorderRoomsApi } from "../api";

export const useSpaceStore = defineStore("space", () => {
  const houses = ref<House[]>([]);
  const rooms = ref<Room[]>([]);
  const activeHouseId = ref<number | null>(null);
  const activeRoomId = ref<number | null>(null);
  const showInactiveSpaces = ref<boolean>(false);

  // 空间锚定 (Space Anchor): 锁定后新录入的物品自动继承此房屋与房间
  const isAnchorLocked = ref<boolean>(false);
  const anchorHouseId = ref<number | null>(null);
  const anchorRoomId = ref<number | null>(null);

  const activeHouse = computed(() =>
    houses.value.find((h) => h.id === activeHouseId.value)
  );

  const hasInactiveSpaces = computed(() =>
    houses.value.some((h) => h.is_active === false) ||
    rooms.value.some((r) => r.is_active === false)
  );

  function isRoomEffectivelyActive(room: Room): boolean {
    const parent = houses.value.find((h) => h.id === room.house_id);
    return (parent?.is_active !== false) && room.is_active !== false;
  }

  const currentRooms = computed(() => {
    if (!activeHouseId.value) return rooms.value;
    return rooms.value.filter((r) => r.house_id === activeHouseId.value);
  });

  const activeRoom = computed(() =>
    rooms.value.find((r) => r.id === activeRoomId.value)
  );

  const anchorHouse = computed(() =>
    houses.value.find((h) => h.id === anchorHouseId.value)
  );

  const anchorRoom = computed(() =>
    rooms.value.find((r) => r.id === anchorRoomId.value)
  );

  async function loadSpaces() {
    try {
      const [hList, rList] = await Promise.all([getHousesApi(), getRoomsApi()]);
      houses.value = hList;
      rooms.value = rList;

      if (hList.length > 0 && !activeHouseId.value) {
        activeHouseId.value = hList[0].id;
      }
    } catch (err) {
      console.error("加载空间数据失败:", err);
    }
  }

  function setAnchor(houseId: number, roomId: number) {
    anchorHouseId.value = houseId;
    anchorRoomId.value = roomId;
    isAnchorLocked.value = true;
  }

  function releaseAnchor() {
    isAnchorLocked.value = false;
    anchorHouseId.value = null;
    anchorRoomId.value = null;
  }

  async function reorderHouses(orderedIds: number[]) {
    const snapshot = [...houses.value];
    const map = new Map(snapshot.map((h) => [h.id, h]));
    houses.value = orderedIds
      .map((id, idx) => {
        const item = map.get(id);
        return item ? { ...item, sort_order: idx + 1 } : null;
      })
      .filter((h): h is House => h !== null);

    try {
      houses.value = await reorderHousesApi(orderedIds);
    } catch (err) {
      houses.value = snapshot;
      throw err;
    }
  }

  async function reorderRooms(houseId: number, orderedIds: number[]) {
    const snapshot = [...rooms.value];
    const targetRooms = snapshot.filter((r) => r.house_id === houseId);
    const otherRooms = snapshot.filter((r) => r.house_id !== houseId);
    const map = new Map(targetRooms.map((r) => [r.id, r]));
    const optimisticTarget = orderedIds
      .map((id, idx) => {
        const item = map.get(id);
        return item ? { ...item, sort_order: idx + 1 } : null;
      })
      .filter((r): r is Room => r !== null);

    rooms.value = [...otherRooms, ...optimisticTarget];
    try {
      const updated = await reorderRoomsApi(houseId, orderedIds);
      rooms.value = [...otherRooms, ...updated];
    } catch (err) {
      rooms.value = snapshot;
      throw err;
    }
  }

  return {
    houses,
    rooms,
    activeHouseId,
    activeRoomId,
    showInactiveSpaces,
    hasInactiveSpaces,
    isRoomEffectivelyActive,
    isAnchorLocked,
    anchorHouseId,
    anchorRoomId,
    activeHouse,
    currentRooms,
    activeRoom,
    anchorHouse,
    anchorRoom,
    loadSpaces,
    setAnchor,
    releaseAnchor,
    reorderHouses,
    reorderRooms,
  };
});

