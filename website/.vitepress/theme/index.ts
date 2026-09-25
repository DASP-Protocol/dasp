import DefaultTheme from 'vitepress/theme';
import Home from './Home.vue';
import '@fontsource-variable/dm-sans';
import '@fontsource/ibm-plex-mono/400.css';
import './style.css';

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) { app.component('Home', Home); }
};
