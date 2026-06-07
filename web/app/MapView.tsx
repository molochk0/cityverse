"use client";

import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { PLACE_META, VORONEZH_CENTER, placeName } from "@/lib/places";
import { CATEGORY_LABELS } from "@/lib/contracts";

type MarkerPlace = {
  id: number;
  cat?: number;
  mode: "held" | "listed" | "harberger";
  mine: boolean;
  inDefault?: boolean;
};

const COLOR = {
  mine: "#238636",
  listed: "#2f81f7",
  harberger: "#a371f7",
  default: "#f85149",
  other: "#8b949e",
};

function colorFor(p: MarkerPlace) {
  if (p.inDefault) return COLOR.default;
  if (p.mine) return COLOR.mine;
  if (p.mode === "listed") return COLOR.listed;
  if (p.mode === "harberger") return COLOR.harberger;
  return COLOR.other;
}

// divIcon (HTML-кружок) вместо дефолтной PNG-иконки Leaflet — заодно обходим
// известную проблему с битыми путями к картинкам маркеров в бандлерах.
function dotIcon(color: string) {
  return L.divIcon({
    className: "place-marker",
    html: `<span style="display:block;width:16px;height:16px;border-radius:50%;background:${color};border:2px solid #0d1117;box-shadow:0 0 0 1px ${color}"></span>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
    popupAnchor: [0, -8],
  });
}

const STATE_LABEL: Record<string, string> = {
  held: "на руках",
  listed: "в продаже",
  harberger: "под Harberger",
};

export default function MapView({ places }: { places: MarkerPlace[] }) {
  return (
    <MapContainer
      center={[VORONEZH_CENTER.lat, VORONEZH_CENTER.lng]}
      zoom={13}
      scrollWheelZoom={false}
      style={{ height: 360, width: "100%", borderRadius: 10 }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {places.map((p) => {
        const meta = PLACE_META[p.id];
        if (!meta) return null;
        return (
          <Marker key={p.id} position={[meta.lat, meta.lng]} icon={dotIcon(colorFor(p))}>
            <Popup>
              <b>{placeName(p.id)}</b>
              <br />
              {p.cat !== undefined ? CATEGORY_LABELS[p.cat] : "—"} ·{" "}
              {p.inDefault ? "дефолт" : STATE_LABEL[p.mode]}
              <br />
              {p.mine ? "твоё место" : "чужое место"}
            </Popup>
          </Marker>
        );
      })}
    </MapContainer>
  );
}
