// Loaded once before every test file (see vite.config.js -> test.setupFiles).
// Adds jest-dom matchers like toBeInTheDocument(), toHaveTextContent(), etc.
import "@testing-library/jest-dom";

// jsdom doesn't implement localStorage mutation events / clearing between files on its
// own in a way that's safe to rely on, so each test clears it explicitly in its own
// beforeEach — this file only wires up the matchers.
