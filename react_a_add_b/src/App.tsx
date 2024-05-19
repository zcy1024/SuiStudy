import './App.css'

import * as React from 'react';
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import Button from '@mui/material/Button';

import { TransactionBlock } from "@mysten/sui.js/transactions";
import { ConnectButton, useCurrentAccount, useSuiClientQuery, useSignAndExecuteTransactionBlock } from '@mysten/dapp-kit';
import _default from '@mui/material/styles/identifier';

function App() {
    const { mutate: signAndExecuteTransactionBlock } = useSignAndExecuteTransactionBlock();
    const account = useCurrentAccount();

    const [numberA, setNumberA] = React.useState("");
    const readNumberA = (event: any) => {
        setNumberA(event.target.value);
    };
    // console.log(numberA);
    const [numberB, setNumberB] = React.useState("");
    const readNumberB = (event: any) => {
        setNumberB(event.target.value);
    };
    // console.log(numberB);
    const [sum, setSum] = React.useState("");
    const calculate = () => {
        moveCall(Number(numberA), Number(numberB), account, signAndExecuteTransactionBlock, setSum);
    };

	return (
		<div>
            <div className='ConnectButton'>
                <ConnectButton />
            </div>

            <Box
                component="form"
                sx={{
                    '& > :not(style)': { m: 1, width: '15ch', left: "33%"},
                }}
                noValidate
                autoComplete="off"
                >
                <TextField id="a" label="a" variant="standard" onChange={readNumberA}/>
                <p className='Symbol'>+</p>
                <TextField id="b" label="b" variant="standard" onChange={readNumberB}/>
                <p className='Symbol'>=</p>
                <TextField id="sum" label="sum" variant="standard" disabled={true} value={sum}/>

                <Button variant="outlined" size="large" className="CalButton" onClick={calculate}>Calculate</Button>
            </Box>

		</div>
	);
}

function moveCall(a: number, b: number, account: any, signAndExecuteTransactionBlock: any, setSum: any) {

    if (!account) {
        setSum("Connect First!!!");
        return;
    }
    
    const txb = new TransactionBlock();
    txb.moveCall({
        target: "0xc20b020f8bf81400cc6c1d63ac37a4802ef873df35abd754ffd37992655b25e4::add::add",
        arguments: [txb.pure(a), txb.pure(b)],
    });
    signAndExecuteTransactionBlock(
    {
        transactionBlock: txb,
        chain: "sui:testnet",
        options: {
            showEvents: true,
        },
    },
    {
        onSuccess: (result: any) => {
            setSum(result.events[0].parsedJson.res);
            // console.log(result.events[0].parsedJson.res);
            // for (let obj of result.objectChanges) {
            //     if (obj.objectType === "0xc20b020f8bf81400cc6c1d63ac37a4802ef873df35abd754ffd37992655b25e4::add::Result") {
            //         // return obj.objectId;
            //         break;
            //     }
            // }
        },
    });

    setSum("waiting...");
    return;
}

// function FindSum(objectId: any) {
//     console.log(objectId);
//     const { data } = useSuiClientQuery("getObject", { id: objectId, options: { showContent: true } });
//     // setSum(data?.data?.content?.fields?.res);
//     return data?.data?.content?.fields?.res;
// }

export default App
