import { test, expect } from '@playwright/test';

test.describe('Agent Dashboard', () => {
  test('loads main dashboard', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('text=Agent Performance Dashboard')).toBeVisible();
  });

  test('displays agent status', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('[data-testid="agent-status"]')).toBeVisible();
  });

  test('shows metrics data', async ({ page }) => {
    await page.goto('/metrics');
    await expect(page.locator('text=Active Agents')).toBeVisible();
  });

  test('Grafana integration works', async ({ page }) => {
    await page.goto('/grafana');
    // Check if Grafana iframe loads or redirects properly
    await expect(page.locator('iframe, [data-testid="grafana-content"]')).toBeVisible();
  });
});
