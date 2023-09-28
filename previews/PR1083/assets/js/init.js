require.config({
    paths: {
        mermaid: "https://cdnjs.cloudflare.com/ajax/libs/mermaid/9.1.2/mermaid"
    }
});
require(['mermaid'], function(mermaid) { mermaid.init() });