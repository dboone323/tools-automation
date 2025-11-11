import { test, expect } from '@playwright/test';

test.describe('Agent Dashboard', () => {
  test('loads main dashboard', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('text=Agent Status Dashboard')).toBeVisible();
  });
});
