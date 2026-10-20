export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const response = await env.ASSETS.fetch(request);

    if (response.status === 404 && (request.method === "GET" || request.method === "HEAD")) {
      if (url.pathname !== "/") {
        return Response.redirect(url.origin + "/", 301);
      }
    }

    return response;
  },
};
