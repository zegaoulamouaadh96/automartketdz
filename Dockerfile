FROM node:18-alpine

WORKDIR /app

COPY backend/package*.json ./

RUN npm install --production

COPY backend/ .

RUN mkdir -p uploads

EXPOSE 3000

CMD ["node", "src/server.js"]
