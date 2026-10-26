import { resourceAPI } from "./glasscraft-api.js";
export default {
  async fetch(request, env) {
    const apiResponse = await resourceAPI(request);
    if (apiResponse) return apiResponse;
    const url = new URL(request.url);
    if (["/gcl", "/gcl/", "/glasscraft", "/glasscraft/", "/glasscraft/index.html"].includes(url.pathname)) return Response.redirect(url.origin + "/", 308);
    if (url.pathname === "/guides/mac-mc-launcher") return Response.redirect(url.origin + "/guides/mac-mc-launcher/", 308);
    if (url.pathname === "/glassdeck") return Response.redirect(url.origin + "/glassdeck/", 308);
    if (url.pathname === "/app" && (request.method === "GET" || request.method === "HEAD")) {
      url.pathname = "/app/";
      return Response.redirect(url.toString(), 308);
    }
    const response = await env.ASSETS.fetch(request);

    if (response.status === 404 && (request.method === "GET" || request.method === "HEAD")) {
      if (url.pathname !== "/" && !url.pathname.startsWith("/app/") && !url.pathname.startsWith("/glasscraft/") && !url.pathname.startsWith("/gcl/") && !url.pathname.startsWith("/glassdeck/") && !url.pathname.startsWith("/guides/")) {
        return Response.redirect(url.origin + "/", 301);
      }
    }

    return response;
  },
};
