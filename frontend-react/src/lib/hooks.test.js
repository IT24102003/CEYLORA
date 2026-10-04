import { describe, it, expect } from "vitest";
import { errorMessage, formatLKR } from "./hooks";

describe("errorMessage", () => {
  it("prefers the backend's message field when present", () => {
    const err = { response: { data: { message: "Email already registered." } } };
    expect(errorMessage(err, "fallback")).toBe("Email already registered.");
  });

  it("falls back to err.message when there is no response body", () => {
    const err = { message: "Network Error" };
    expect(errorMessage(err, "fallback")).toBe("Network Error");
  });

  it("falls back to the provided fallback when nothing else is available", () => {
    expect(errorMessage({}, "Login failed.")).toBe("Login failed.");
    expect(errorMessage(undefined, "Login failed.")).toBe("Login failed.");
  });
});

describe("formatLKR", () => {
  it("formats a plain number with the LKR prefix and thousands separators", () => {
    expect(formatLKR(15000)).toBe("LKR 15,000");
  });

  it("treats null/undefined as zero instead of throwing", () => {
    expect(formatLKR(null)).toBe("LKR 0");
    expect(formatLKR(undefined)).toBe("LKR 0");
  });

  it("respects the digits option", () => {
    expect(formatLKR(1234.5, 2)).toBe("LKR 1,234.5");
  });
});
