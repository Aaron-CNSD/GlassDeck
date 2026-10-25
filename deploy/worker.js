import { resourceAPI } from "./glasscraft-api.js";
export default {
  async fetch(request, env) {
    const apiResponse = await resourceAPI(request);
    if (apiResponse) return apiResponse;
    const url = new URL(request.url);
    if (url.pathname === "/glasscraft") return Response.redirect(url.origin + "/glasscraft/", 308);
    if (url.pathname === "/app" && (request.method === "GET" || request.method === "HEAD")) {
      url.pathname = "/app/";
      return Response.redirect(url.toString(), 308);
    }
    const response = await env.ASSETS.fetch(request);

    if (response.status === 404 && (request.method === "GET" || request.method === "HEAD")) {
      if (url.pathname !== "/" && !url.pathname.startsWith("/app/") && !url.pathname.startsWith("/glasscraft/")) {
        return Response.redirect(url.origin + "/", 301);
      }
    }

    return response;
  },
};
