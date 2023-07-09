/*##############################################################################
# File: db.js                                                                  #
# Project: MyZap2.0                                                            #
# Created Date: 2021-06-21 14:12:20                                            #
# Author: Eduardo Policarpo                                                    #
# Last Modified: 2021-06-21 18:27:30                                           #
# Modified By: Eduardo Policarpo                                               #
##############################################################################*/


import config from "../config.js";
import { initializeApp } from 'firebase/app';
import { deleteDoc, 
    getFirestore, 
    collection, 
    getDocs, 
    setDoc, 
    doc, 
    getDoc, 
    addDoc 
} from 'firebase/firestore/lite';

let xapp = null
let xdb = null
let xSessions = null
let xsnapshot = null


if(config.apikey === undefined ){

}else{
  xapp = initializeApp(config.firebaseConfig);
  xdb = getFirestore(xapp);

  xSessions = await collection(xdb,config.sessions_field);
  xsnapshot = await getDocs(xSessions);

}

const Sessions = xsnapshot
const snapshot = xsnapshot
const app = xapp
const db = xdb

export {addDoc};
export {setDoc};
export {getDoc};
export {doc};
export {deleteDoc};
export {db};
export {snapshot};
export {Sessions};
export default{ app };

