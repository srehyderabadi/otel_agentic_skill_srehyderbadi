import http from "k6/http";
import { check, sleep } from "k6";
import { randomItem } from "https://jslib.k6.io/k6-utils/1.2.0/index.js";

export const options = {
  scenarios: {
    mixed_traffic: {
      executor: "constant-arrival-rate",
      rate: 150, // 150 requests
      timeUnit: "1m", // per 1 minute
      duration: "5m", // run for 5 minutes
      preAllocatedVUs: 10,
      maxVUs: 50,
    },
  },
  // No thresholds here because we explicitly EXPECT errors
};

const BASE_URL = __ENV.BASE_URL || "http://localhost:80";

const endpoints = [
  // Valid endpoints (expected 200)
  { url: "/order/biryani/chicken", expectedStatus: 200 },
  { url: "/order/biryani/mutton", expectedStatus: 200 },
  { url: "/order/biryani/veg", expectedStatus: 200 },
  { url: "/order/chai/irani", expectedStatus: 200 },
  { url: "/order/chai/lemon", expectedStatus: 200 },
  { url: "/order/chai/masala", expectedStatus: 200 },

  // Invalid endpoints (expected 500)
  { url: "/order/pizza/cheese", expectedStatus: 500 },
  { url: "/order/pasta/white", expectedStatus: 500 },
  { url: "/order/coffee/filter", expectedStatus: 500 },
  { url: "/order/biryani/paneer", expectedStatus: 500 },
  { url: "/order/biryani/ulavacharu", expectedStatus: 500 },
  { url: "/order/biryani/bagara", expectedStatus: 500 },
  { url: "/order/chai/cappucino", expectedStatus: 500 },
  { url: "/order/chai/elachi", expectedStatus: 500 },
  { url: "/order/chai/blacktea", expectedStatus: 500 },
];

export default function () {
  const endpointData = randomItem(endpoints);
  const res = http.get(`${BASE_URL}${endpointData.url}`);

  // Check the status against what we expected for Grafana observability
  if (endpointData.expectedStatus === 200) {
    check(res, {
      "is status 200 (Healthy)": (r) => r.status === 200,
    });
  } else {
    check(res, {
      "is status 500 (Expected Error)": (r) => r.status === 500,
    });
  }

  sleep(Math.random() * 0.5);
}
