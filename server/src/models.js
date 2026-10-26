/// 只放行 Flash 和 Flash-Lite（Yang 的决定，绝不用 Pro）。配置写错了也拦住。
export function isAllowedModel(model) {
  return typeof model === "string" && /^gemini-[a-z0-9.-]+$/.test(model)
    && /-flash(-|$)/.test(model) && !model.includes("pro");
}
