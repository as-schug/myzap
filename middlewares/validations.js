/*
 * @Author: Eduardo Policarpo
 * @contact: +55 43996611437
 * @Date: 2021-05-10 18:09:49
 * @LastEditTime: 2021-06-07 03:18:01
 */
import Sessions from '../controllers/sessions.js'
import dotenv from "dotenv";
import { existsSync } from 'node:fs';

dotenv.config();
let engine = process?.env?.ENGINE;

const checkParams = async (req, res, next) => {
    let session = req?.body?.session
    let data = Sessions.getSession(session)
    let status = data ? data.status : "";
    let exists = existsSync('./tokens/' + session)
    if (!session) {
        return res.status(401).json({
	  response: false,
	  result: 401,
          status: status,
	  exists: exists,
	  message: 'Sessão não informada.' });
    }
    else if (Sessions.session.length === 0 || !data || !data.client) {
        return res.status(503).json({
	    response:false,
	    result: 503,
	    dh: data.dh,
	    status: status,
	    exists: exists,	    
            message: session + ': O Serviço para a sessao esta offLine.'
        })
    }
    else if (data.sessionkey != req.headers['sessionkey']) {
        return res.status(401).json({
	    response: false,
            result: 401,
	    status: status,
	    exists: exists,	     
            message: session+": Não autorizado. Verifique se o nome da sessão e o sessionkey estão corretos"
        })
    }
    else {
        if (engine === '1') {
            //const client = await data.client.isOnline();
            if (!data.client) {
                return res.status(400).json({
                    response: false,
		    result: 401,
		    status: status,
                    exists: exists,
		    message: session+': A sessão informada não está ativa.'
                })
            }
            else {
                next();
            }
        }
        else {
            const client = await data?.client?.isConnected();
            if (!client) {
                return res.status(400).json({
                    response: false,
                    result: 401,
		    status: status,
		    exists: exists,
		    message: session+': A sessão informada não está ativa.'
                })
            }
            else {
                next();
            }
        }
    }
}
//checar se o numero existe no whats ...... isso no whatsappwebjs
const checkRegisteredNumber = async function (req, res) {
    let data = Sessions.getSession(req.body.session)
    const isRegistered = await data?.client?.isRegisteredUser(req.body.number);
    return isRegistered;
}

export { checkParams }
