/**
 * 物迹 (TraceItem) 端侧图片智能等比压缩工具 (ADR 0003)
 * - 限制长边 <= 1600px
 * - 统一转换为 JPEG 格式，画质 80%~85% (默认 0.82)
 * - 基于原生 HTML5 Canvas，零外部依赖，极速轻量
 */

import mediaLimits from "@shared/media_limits.json";

export interface CompressionOptions {
  maxDimension?: number;
  quality?: number;
}

export async function compressImage(
  file: File,
  options: CompressionOptions = {}
): Promise<File> {
  const {
    maxDimension = mediaLimits.imageMaxLongEdge,
    quality = mediaLimits.imageJpegQuality / 100,
  } = options;

  if (!file.type.startsWith("image/")) {
    return file;
  }

  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);

    img.onload = () => {
      URL.revokeObjectURL(url);
      let { width, height } = img;

      // 若长边超过限制，等比计算新宽高
      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = Math.round((height * maxDimension) / width);
          width = maxDimension;
        } else {
          width = Math.round((width * maxDimension) / height);
          height = maxDimension;
        }
      }

      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;

      const ctx = canvas.getContext("2d");
      if (!ctx) {
        resolve(file);
        return;
      }

      // 填充纯白背景防止透明 PNG 转 JPEG 后出现黑底
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, width, height);
      ctx.drawImage(img, 0, 0, width, height);

      canvas.toBlob(
        (blob) => {
          if (!blob) {
            resolve(file);
            return;
          }

          const baseName = file.name.replace(/\.[^/.]+$/, "");
          const compressedFile = new File([blob], `${baseName}.jpg`, {
            type: "image/jpeg",
            lastModified: Date.now(),
          });

          // 若原文件更小且已是 JPEG 则保留原文件
          if (compressedFile.size > file.size && file.type === "image/jpeg") {
            resolve(file);
          } else {
            resolve(compressedFile);
          }
        },
        "image/jpeg",
        quality
      );
    };

    img.onerror = (err) => {
      URL.revokeObjectURL(url);
      reject(err);
    };

    img.src = url;
  });
}

