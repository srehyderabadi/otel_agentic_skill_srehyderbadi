import http from "k6/http";
import { check, sleep } from "k6";

// Using randomItem from k6-utils standard library
import { randomItem } from "https://jslib.k6.io/k6-utils/1.2.0/index.js";

export const options = {
  scenarios: {
    healthy_traffic: {
      executor: "constant-arrival-rate",
      rate: 200, // 200 requests
      timeUnit: "1m", // per 1 minute
      duration: "5m", // run for 5 minutes
      preAllocatedVUs: 10,
      maxVUs: 50,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"], // Almost no failures expected
  },
};

const BASE_URL = __ENV.BASE_URL || "http://localhost:80";

const validEndpoints = [
  "/order/biryani/chicken",
  "/order/biryani/mutton",
  "/order/biryani/veg",
  "/order/chai/irani",
  "/order/chai/lemon",
  "/order/chai/masala",
];

export default function () {
  const endpoint = randomItem(validEndpoints);
  const res = http.get(`${BASE_URL}${endpoint}`);

  check(res, {
    "is status 200": (r) => r.status === 200,
  });

  // slightly randomized sleep to simulate different users clicking around
  sleep(Math.random() * 0.5);
}
