import axios from "axios";
import type { ApiResponse } from "../types";

export const api = axios.create({
  baseURL: "/api",
  timeout: 30000,
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("traceitem_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("traceitem_token");
      localStorage.removeItem("traceitem_user");
      if (window.location.pathname !== "/login") {
        window.location.href = "/login";
      }
    }
    const message = error.response?.data?.message || error.message || "网络请求发生异常";
    return Promise.reject(new Error(message));
  }
);

