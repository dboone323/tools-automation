const http = require("http");
const fs = require("fs");
const path = require("path");

const server = http.createServer((req, res) => {
  console.log(`Request: ${req.url}`);

  // Serve dashboard.html as the root
  if (req.url === "/" || req.url === "/dashboard.html") {
    const filePath = path.join(__dirname, "dashboard.html");
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("File not found");
        return;
      }
      res.writeHead(200, { "Content-Type": "text/html" });
      res.end(data);
    });
  }
  // Serve other files
  else {
    const filePath = path.join(__dirname, req.url);
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("File not found");
        return;
      }
      // Determine content type based on file extension
      const ext = path.extname(req.url);
      let contentType = "text/plain";
      switch (ext) {
        case ".html":
          contentType = "text/html";
          break;
        case ".css":
          contentType = "text/css";
          break;
        case ".js":
          contentType = "application/javascript";
          break;
        case ".json":
          contentType = "application/json";
          break;
      }
      res.writeHead(200, { "Content-Type": contentType });
      res.end(data);
    });
  }
});

const PORT = 8082;
server.listen(PORT, () => {
  console.log(`Dashboard server running at http://localhost:${PORT}`);
});
