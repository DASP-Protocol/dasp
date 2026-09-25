import DefaultTheme from 'vitepress/theme';
import SiteLayout from './SiteLayout.vue';
import Home from './Home.vue';
import WalkthroughStory from './WalkthroughStory.vue';
import '@fontsource-variable/dm-sans';
import '@fontsource/ibm-plex-mono/400.css';
import './style.css';

export default {
  extends: DefaultTheme,
  Layout: SiteLayout,
  enhanceApp({ app }) {
    app.component('Home', Home);
    app.component('WalkthroughStory', WalkthroughStory);
  }
};
