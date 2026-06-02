/*
 * @Author: Eduardo Policarpo
 * @contact: +55 43996611437
 * @Date: 2021-05-20 18:05:16
 * @LastEditTime: 2021-06-07 03:18:22
 */

import whatsconnet from "./engines/WppConnect.js";

import routeWhatsconnet from "./routers/WppConnect.js";

// A única engine suportada é o WPPConnect. Mantemos a chave numérica `2`
// por compatibilidade com os .env existentes (ENGINE=2).
var engines = {
    2: {
        descricao: "Engine WPPConnect",
        motor: whatsconnet,
        router: routeWhatsconnet.Router,
    },
};

export default { engines };
