// Метаданные мест Воронежа по tokenId (порядок сидинга в Deploy.s.sol).
// Парки — приблизительно реальные точки на карте; кальянные — плейсхолдеры (как и их названия).
// Временно живёт здесь; когда сделаем метаданные на IPFS — переедет в tokenURI.
export type PlaceMeta = { name: string; lat: number; lng: number };

export const PLACE_META: Record<number, PlaceMeta> = {
  0: { name: "Центральный парк (Динамо)", lat: 51.6772, lng: 39.1959 },
  1: { name: "Парк «Алые паруса»", lat: 51.6709, lng: 39.2148 },
  2: { name: "Парк «Орлёнок»", lat: 51.6585, lng: 39.2057 },
  3: { name: "Кольцовский сквер", lat: 51.667, lng: 39.2106 },
  4: { name: "Кальянная №1", lat: 51.662, lng: 39.193 },
  5: { name: "Кальянная №2", lat: 51.6555, lng: 39.1995 },
  6: { name: "Кальянная №3", lat: 51.67, lng: 39.188 },
  7: { name: "Кальянная №4", lat: 51.6505, lng: 39.21 },
};

export const VORONEZH_CENTER = { lat: 51.6608, lng: 39.2003 };

export function placeName(id: number) {
  return PLACE_META[id]?.name ?? `Место #${id}`;
}
