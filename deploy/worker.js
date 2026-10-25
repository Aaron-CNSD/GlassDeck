export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/app" && (request.method === "GET" || request.method === "HEAD")) {
      url.pathname = "/app/";
      return Response.redirect(url.toString(), 308);
    }
    const response = await env.ASSETS.fetch(request);

    if (response.status === 404 && (request.method === "GET" || request.method === "HEAD")) {
      if (url.pathname !== "/" && !url.pathname.startsWith("/app/")) {
        return Response.redirect(url.origin + "/", 301);
      }
    }

    return response;
  },
};
