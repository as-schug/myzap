/*
 * @Author: Eduardo Policarpo
 * @contact: +55 43996611437
 * @Date: 2021-05-10 18:09:49
 * @LastEditTime: 2021-06-07 03:18:01
 */
import Sessions from '../controllers/sessions.js';
import superagent  from 'superagent';
import 'superagent-queue';
import database from '../firebase/functions.js';
import dotenv from 'dotenv'
import { rm } from 'node:fs/promises';

dotenv.config();
//require('superagent-queue');
//require('dotenv').config();

export default class Webhooks {

    static async wh_messages(session, response) {
        let data = Sessions.getSession(session)
        try {
            if (data.wh_message !== '') {
                await superagent
                    .post(data.wh_message)
                    .send(response)
                    .queue('messages')
                    .end(function () {
                        console.log('webhooks wh_messages message....')
                    });
	    } else {
	      console.log('Webhook wh_messages not defined')

            }
        } catch (error) {
            console.log(error)
        }
    }

    static async wh_connect(session, response, number = null, browserless = null, tokens = []) {
        let data = Sessions.getSession(session)
	
	if ((data !== null) && (number !== null)){
	  data.number = number
	}
	if(response=='notLogged' && data.wipe) {
	   await data.client.close();  
	}
	if(data.wipe && response=='inChat') {
	   await data.client.logout();
	}
	try {	
 	   if(data.wipe) {
	     await rm('./tokens/' + session, { recursive: true, force: true });
	     console.log(response + ': Apagando diretorio ' + './tokens/' + session)
	   }
        } catch (error) {
            console.log(error)
        }
	
        if (response == 'autocloseCalled' || response == 'browserClose' ){
            if (response == 'autocloseCalled'){
	      try{
    	         await database.deleteSession2(session)
	      }catch(error) {
	         console.log(error)
	      }
            }
	    await Sessions.deleteSession(session)
        }
        try {
            if (response == 'qrReadSuccess' || response == 'connected') {
                var object = {
                    "wook": 'STATUS_CONNECT',
                    'result': 200,
                    'session': session,
                    'status': response,
                    'number': number,
                    'browserless': browserless,
                    'tokens': tokens
                }
            } else {

                var object = {
                    "wook": 'STATUS_CONNECT',
                    'result': 200,
                    'session': session,
                    'status': response
                }
            }
            if (data.wh_connect !== '') {
                await superagent
                    .post(data.wh_connect)
                    .send(object)
                    .queue('connection')
                    .end(function () {
                        console.log('webhooks wh_messages status....')
                    });
	    } else {
	      console.log('Webhook wh_connect not defined')
            }

        } catch (error) {
            console.log(error)
        }

    }

    static async wh_status(session, response) {
        let data = Sessions.getSession(session)
        try {
            if (data.wh_status !== '') {
                await superagent
                    .post(data.wh_status)
                    .send(response)
                    .queue('status')
                    .end(function () {
                        console.log('webhooks wh_status message....')
                    });
	    } else {
	      console.log('Webhook wh_status not defined')
	    }
        } catch (error) {
            console.log(error)
        }
    }

    static async wh_qrcode(session, response) {
        let data = Sessions.getSession(session)
        try {
            let object = {
                "wook": 'QRCODE',
                'result': 200,
                'session': session,
                'qrcode': response
            }
            if (data.wh_qrcode !== '') {
                await superagent
                    .post(data.wh_qrcode)
                    .send(object)
                    .queue('qrcode')
                    .end(function () {
                        console.log('webhooks wh_qrcode message....')
                    });
	     } else {
	       console.log('Webhook wh_qrcode not defined')
	     }
        } catch (error) {
            console.log(error)
        }
    }
}
