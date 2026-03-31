import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { window } from '@kit.ArkUI';
import { CacheManager } from '../utils/CacheManager';
import { ImageCacheManager } from '../utils/ImageCacheManager';
import { CookieManager } from '../utils/CookieManager';

const DOMAIN: number = 0xFF00;
const TAG: string = '[EntryAbility]';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    CacheManager.getInstance().init(this.context);
    ImageCacheManager.getInstance().init(this.context);
    CookieManager.getInstance().init(this.context);

    windowStage.loadContent('pages/BoardListPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    this.setImmersiveWindow(windowStage);
  }

  private async setImmersiveWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();

      await mainWindow.setWindowLayoutFullScreen(true);

      const systemBarProperties: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        statusBarContentColor: '#000000',
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#000000',
        isStatusBarLightIcon: false,
        isNavigationBarLightIcon: false
      };

      
      await mainWindow.setWindowSystemBarProperties(systemBarProperties);
      
      await mainWindow.setWindowSystemBarEnable(['status', 'navigation']);
      
      hilog.info(DOMAIN, TAG, 'Immersive window set successfully');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to set immersive window: %{public}s', err.message);
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
