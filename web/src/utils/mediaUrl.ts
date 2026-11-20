export function withAuthMediaUrl(url?: string | null): string {
  if (!url) return "";
  if (url.startsWith("blob:") || url.startsWith("data:")) return url;
  const token = localStorage.getItem("traceitem_token") || "";
  if (!token || !url.includes("/api/media/file/")) return url;
  const sep = url.includes("?") ? "&" : "?";
  return `${url}${sep}token=${encodeURIComponent(token)}`;
}

export function resolveAttachmentUrl(att: any): string {
  if (!att) return "";
  const raw = att.url || (att.file_path ? `/api/media/file/${att.file_path}` : "");
  return withAuthMediaUrl(raw);
}

export function resolveAttachmentThumb(att: any): string {
  if (!att) return "";
  const raw =
    att.thumbnail_url ||
    att.url ||
    (att.thumbnail_path ? `/api/media/file/${att.thumbnail_path}` : "") ||
    (att.file_path ? `/api/media/file/${att.file_path}` : "");
  return withAuthMediaUrl(raw);
}

