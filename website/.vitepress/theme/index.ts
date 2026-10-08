import DefaultTheme from 'vitepress/theme';
import SiteLayout from './SiteLayout.vue';
import Home from './Home.vue';
import CommandOverview from './CommandOverview.vue';
import CommandTrace from './CommandTrace.vue';
import CloudEventsHelp from './CloudEventsHelp.vue';
import CloudEventAnatomy from './CloudEventAnatomy.vue';
import MessageExamples from './MessageExamples.vue';
import '@fontsource-variable/dm-sans';
import '@fontsource/ibm-plex-mono/400.css';
import './style.css';

export default {
  extends: DefaultTheme,
  Layout: SiteLayout,
  enhanceApp({ app }) {
    app.component('Home', Home);
    app.component('CommandOverview', CommandOverview);
    app.component('CommandTrace', CommandTrace);
    app.component('CloudEventsHelp', CloudEventsHelp);
    app.component('CloudEventAnatomy', CloudEventAnatomy);
    app.component('MessageExamples', MessageExamples);
  }
};
