import './App.css'

import * as React from 'react';
import Button from '@mui/material/Button';
import ButtonGroup from '@mui/material/ButtonGroup';
import Box from '@mui/material/Box';
import CircularProgress from '@mui/material/CircularProgress';
import Alert from '@mui/material/Alert';

import { SuiClientProvider, WalletProvider } from '@mysten/dapp-kit';
import { getFullnodeUrl } from '@mysten/sui.js/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ConnectButton, useCurrentAccount, useSuiClientQuery } from '@mysten/dapp-kit';

const MaxRow = 10;
const MaxList = 20;

function App() {
	const queryClient = new QueryClient();
	const [network, setNetwork] = React.useState("testnet");
	const networks = {
		testnet: { url: getFullnodeUrl('testnet') },
		mainnet: { url: getFullnodeUrl('mainnet') },
	};

	return (
		<div>
			<QueryClientProvider client={queryClient}>
				<SuiClientProvider networks={networks} network={network as keyof typeof networks} onNetworkChange={(network) => setNetwork(network)}>
					<WalletProvider>
						<div className='ConnectButton'>
							<ConnectButton />
						</div>
						<MineClearance />
						<FeedBack />
					</WalletProvider>
				</SuiClientProvider>
			</QueryClientProvider>
		</div>
	);
}

function MineClearance() {
	const account = useCurrentAccount();

	const StartGame = () => {
		document.getElementById('NotConnect')!.hidden = true;

		if (!account) {
			document.getElementById('NotConnect')!.hidden = false;
			return;
		}

		// console.log("Connected");
		return;
	};

	return (
		<div className='Game'>
			<div className='StartButton'>
				<Button variant="contained" onClick={StartGame}>Game</Button>
				<br></br>
				<i id="NotConnect" hidden={true}>Please Connect First!!!</i>
			</div>
			<div id='Checkerboard'>
				<DrawCheckerboard />
			</div>
		</div>
	);
}

function DrawCheckerboard() {
	const clickBoard = (event: any) => {
		const r = event.target.getAttribute('button-key')
		const l = event.target.parentElement.getAttribute('button-key');
		console.log(`(${r}, ${l})`);

		let str1 = event.currentTarget.innerHTML.split('<', 1)[0];
		const str2 = event.currentTarget.innerHTML.substring(str1.length);
		str1 = str1 == "x" ? "1" : "x";
		const str = str1.concat(str2);
		console.log(str);
		event.currentTarget.innerHTML = str;

		event.target.disabled = true;

		HiddenFeedBack();
		ShowFeedBack("circular_progress");
		// ShowFeedBack("success_alert");
		// ShowFeedBack("encourage_alert");
		// ShowFeedBack("failure_alert");
	}

	const childboard = [];
	let i = 1;
	while (i <= MaxRow) {
		childboard.push(<Button key={i} button-key={i} size="large" onClick={clickBoard} sx={{width: "1px"}}>&nbsp;</Button>);
		i += 1;
	}

	const checkerboard = [];
	let j = 1;
	while (j <= MaxList) {
		checkerboard.push(<ButtonGroup orientation='vertical' aria-label='Vertical button group' variant='outlined' key={j} button-key={j}>{childboard}</ButtonGroup>);
		j += 1;
	}

	return (
		<Box>
			{checkerboard}
		</Box>
	);
}

function FeedBack() {
	return (
		<div className='FeedBack'>
			<div id="circular_progress" hidden={true}>
				<CircularProgress />
			</div>
			<div id="success_alert" className='SuccessAlert' hidden={true}>
				<Alert variant="outlined" severity="success">
					Congratulations on your successful mine clearance!
				</Alert>
			</div>
			<div id="encourage_alert" className='EncourageAlert' hidden={true}>
				<Alert variant="outlined" severity="info">
					Fortunately you didn't touch a landmine, please consider your next step!
				</Alert>
			</div>
			<div id="failure_alert" className='FailureAlert' hidden={true}>
				<Alert variant="outlined" severity="error">
					Unfortunately, the minesweeper failed!
				</Alert>
			</div>
		</div>
	);
}

function ShowFeedBack(id: string) {
	// document.getElementById(id)!.hidden = false;
	if (id == "circular_progress")
		document.getElementById(id)!.hidden = false;
	else
		document.getElementById(id)!.style.display = "inline-flex";
}

function HiddenFeedBack() {
	document.getElementById("circular_progress")!.hidden = true;
	// document.getElementById("success_alert")!.hidden = true;
	// document.getElementById("encourage_alert")!.hidden = true;
	// document.getElementById("failure_alert")!.hidden = true;
	document.getElementById("success_alert")!.style.display = "none";
	document.getElementById("encourage_alert")!.style.display = "none";
	document.getElementById("failure_alert")!.style.display = "none";
}

export default App
