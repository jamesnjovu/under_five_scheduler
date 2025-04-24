
import AOS from "../../vendor/aos";

let AOSHook = {
    mounted() {
        AOS.init({ once: true });
    },
    updated() {
        AOS.refresh();
    }
};

export default AOSHook;