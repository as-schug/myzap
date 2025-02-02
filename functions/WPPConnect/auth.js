﻿/*
 * @Author: Eduardo Policarpo
 * @contact: +55 43996611437
 * @Date: 2021-05-10 18:09:49
 * @LastEditTime: 2021-06-07 03:18:01
 */
import Sessions from '../../controllers/sessions.js';
import config from '../../config.js';
import engine from'../../engines/WppConnect.js';
import { setDoc, db, doc } from '../../firebase/db.js';
import { rm } from 'node:fs/promises';
import fs from 'fs';
import { testHas } from '../../config.js'


export default class Auth {

    static async start(req, res) {
        try {
	    let date = new Date();
	    let unixTimestamp = Math.floor(date.getTime() / 1000);
	    let session = req.body.session    
	    let timeout = req.body.timeout
	    if (testHas(timeout)){
	       timeout=config.timeout
	    }
	    
	    timeout=+timeout

            if (Object.keys(config.firebaseConfig).length === 0) {
                res.status(401).json({
                    result: 401,
                    "status": "FAIL",
                    "reason": "favor preencher as credencias de acesso ao Firebase"
                })
            } else {
                if (req.headers['apitoken'] === config.token) {
                    
                    let existSession = Sessions.checkSession(session)
                    if (!existSession) {
                        init(session)
                    } else {
                        let data = Sessions.getSession(session)
			
			if((!data.client) && ((unixTimestamp-data.dh)>120) ) {
			   init(session)
			   return 
			}
      		        console.log(session + ': Session already started ')

                        res.status(409).json({
                                result: 409,
                                "status": "FAIL",
                                "reason": "there is already a session with that name: " + session,
                                "status": data.status
                            })
                     }
    
                    async function init(session) {		        
			
			let objeto = {			   
			   MYSESSION: session,
			   MYSESSIONKEY: req.headers['sessionkey'],
			   MYWHSTATUS: req.body.wh_status,
			   MYWHMESSAGE: req.body.wh_message,
			   MYWHQRCODE: req.body.wh_qrcode,
			   MYWHCONNECT: req.body.wh_connect
			}
			let data = '';
			for (let prop in objeto) {
			   data += `${prop}="${objeto[prop]}"\n`
			}
			let arquivo = './tokens/' + session + '/session.cfg'
		        	
			console.log('DH: ' + unixTimestamp);
                        Sessions.checkAddUser(session)
                        Sessions.addInfoSession(session, {
                            apitoken: req.headers['apitoken'],
			    client: false,
			    dh: unixTimestamp,
			    timeout: timeout,
			    autologoff: timeout+unixTimestamp,
                            sessionkey: req.headers['sessionkey'],
                            wh_status: req.body.wh_status,
                            wh_message: req.body.wh_message,
                            wh_qrcode: req.body.wh_qrcode,
                            wh_connect: req.body.wh_connect,
                            wa_browser_id: req.headers['wa_browser_id'] ? req.headers['wa_browser_id'] : '',
                            wa_secret_bundle: req.headers['wa_secret_bundle'] ? req.headers['wa_secret_bundle'] : '',
                            wa_token_1: req.headers['wa_token_1'] ? req.headers['wa_token_1'] : '',
                            wa_token_2: req.headers['wa_token_2'] ? req.headers['wa_token_2'] : '',
                        })
    
                        let response = await engine.start(req, res, session)
			
			if (response != undefined) {
                            let data = {
                                'session': session,
                                'apitoken': req.headers['apitoken'],
                                'sessionkey': req.headers['sessionkey'],
                                'wh_status': req.body.wh_status,
                                'wh_message': req.body.wh_message,
                                'wh_qrcode': req.body.wh_qrcode,
                                'wh_connect': req.body.wh_connect,
                                'WABrowserId': response.WABrowserId,
                                'WASecretBundle': response.WASecretBundle,
                                'WAToken1': response.WAToken1,
                                'WAToken2': response.WAToken2,
                                'Engine': process.env.ENGINE,
				timeout: timeout,
                            }
			     if(config.apikey === undefined ) {
			       let datajs = JSON.stringify(data,null,2)
			       arquivo = './tokens/' + session + '/session.js'
			       fs.writeFileSync(arquivo, datajs)
			       await console.log('arquivo js criado com sucesso: ' + arquivo)			
			    } else {
			      arquivo = 'firebase' 
                              await setDoc(doc(db, config.sessions_field, session), data);
			    } 
			     
                            res.status(200).json({
                                "result": 200,
                                "status": "CONNECTED",
                                "response": `Sessão ${session} gravada com sucesso em ${arquivo}`
                            })
    
                        }
                    }
                }
                else {
                    req.io.emit('msg', {
                        result: 400,
                        "status": "FAIL",
                        "reason": "Unauthorized, please check the API TOKEN"
                    })
                    res.status(401).json({
                        result: 401,
                        "status": "FAIL",
                        "reason": "Unauthorized, please check the API TOKEN"
                    })
                }
            }
    
        } catch (error) {
            res.status(500).json({
                result: 500,
                "status": "FAIL",
                "reason": error.message
            })
        }
    }

    static async logoutSession(req, res) {
        let data = Sessions.getSession(req.body.session)
        try {
            await data.client.logout();
            Sessions.addInfoSession(data.session, {
                        status: desconnectedMobile
                    })
            res.status(200).json({
                status: true,
                message: "Sessão Fechada com sucesso"
            });
        } catch (error) {
            res.status(400).json({
                status: false,
                message: "Error ao fechar sessão", error
            });
        }
        try {
            await data.client.close();
            rm('./tokens/' + data.session, { recursive: true, force: true });
        } catch (error) {
        }
    }

    static async closeSession(req, res) {
        let session = req.body.session;
        let data = Sessions.getSession(session)
        try {
           if((data.client != null) && (data.client !==undefined) &&(data.client!==false)) {
            await data.client.close();
           } else {
               Sessions.deleteSession(data.session)
               rm('./tokens/' + data.session, { recursive: true, force: true });
           }
            res.status(200).json({
                status: true,
                message: "Sessão Fechada com sucesso"
            });
        } catch (error) {
            res.status(400).json({
                status: false,
                message: "Error ao fechar sessão", error
            });
        }
    }

    static async getQrCode(req, res) {
        let session = req.query.session;
        let sessionkey = req.query.sessionkey;
        let data = Sessions.getSession(session)
        if (!session) {
            return res.status(401).json({
                "result": 401,
                "messages": "Não autorizado, verifique se o nome da sessão esta correto"
            })
        }
        else
            if (data.sessionkey != sessionkey) {
                return res.status(401).json({
                    "result": 401,
                    "messages": "Não autorizado, verifique se o sessionkey esta correto"
                })
            }
            else {
                try {
                    var img = Buffer.from(data.qrCode.replace(/^data:image\/(png|jpeg|jpg);base64,/, ''), 'base64');
                    res.writeHead(200, {
                        'Content-Type': 'image/png',
                        'Content-Length': img.length
                    });
                    res.end(img);
                } catch (ex) {
                    return res.status(400).json({
                        response: false,
                        message: "Error ao recuperar QRCode !"
                    });
                }
            }

    }

    static async getSessionState(req, res) {
        let session = req.body.session
	let data = Sessions.getSession(session)
        try {
	    let exists = fs.existsSync('./tokens/' + session)
            const client = data.client
            if (client == null || data.status == null)
                return res.status(200).json({
		    response: false,
                    status: 'CLOSED',
		    exists: exists,
		    number: '',
		    dh: data.dh,
                    qrcode: null
                });
            return res.status(200).json({	        
	        response: data.status === 'inChat'?true:false,
		result: 200,
		exists: exists,
		dh: data.dh,
		number: data.number,
		timeout: data.timeout,
		autologoff: data.autologoff,
                status: data.status
            });
        } catch (ex) {
            return res.status(400).json({
                response: false,
		status: 'unknown',
		exists: exists,
		dh: data.dh,
		number: data.number,
                message: 'Exception' + ex
            });
        }
    }
    static async wipeData(req, res) {
        let session = req.body.session;
        let data = await Sessions.getSession(session) 
        try {
    	   await console.log('wipeData for session ' + session)
           if (!session) {
              return res.status(401).json({
                 status: false,
                 message: "invalid session"
              });
           }
  	   if(data!=false) {
             console.log('data exists for session ' + session)
             console.log('data.client for session ' + session + ': ' + data.client)
             Sessions.addInfoSession(session, {
                wipe: true
             })
             if(data.client) {
        	console.log('data.client exists for session ' + session)
                await data.client.logout();
	     }
           }
           rm('./tokens/' + session, { recursive: true, force: true });     
              return res.status(200).json({
                 status: true,
                 message: "done"
              });
        } catch (error) {
            return res.status(200).json({
                status: false,
                message: "Error", 
		error: error
            });
        }
    }

    static async checkConnectionSession(req, res) {
        let data = Sessions.getSession(req.body.session)
        try {
            await data.client.isConnected();
            return res.status(200).json({
                status: true,
                message: "Connected"
            });
        } catch (error) {
            return res.status(200).json({
                status: false,
                message: "Disconnected"
            });
        }
    }
    static async showAllSessions(req, res) {
        // let data = Sessions.getAll();
        // const allSessions = data.forEach(element => {
        //     return ({ session: element.session, status: element.status })

        // });
        // console.log(allSessions);
        // return res.status(200).json(allSessions);

        //res.status(200).json({ sessions: Sessions.getAll() })

        // const allSessions = await clientsArray.map((client) => {
        //     console.log(client);
        //     return client.session;
        // });

        // console.log(allSessions);
        // return res.status(200).json(allSessions);
    }
}

