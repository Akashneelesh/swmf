import {
    constants,
    Provider,
    Contract,
    Account,
    json,
    shortString,
    RpcProvider,
    hash,
} from "starknet";
import * as fs from "fs";
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

dotenv.config();

async function main() {
    const provider = new RpcProvider({
        nodeUrl: process.env.RPC_URL,
    });

    const ci = await provider.getChainId();
    console.log("chain Id =", ci);

    const accountAddress = process.env.ACCOUNT_ADDRESS;
    const privateKey = process.env.PRIVATE_KEY;

    if (!accountAddress || !privateKey) {
        throw new Error("Missing environment variables");
    }

    const account0 = new Account(provider, accountAddress, privateKey);
    console.log("existing_ACCOUNT_ADDRESS=", accountAddress);
    console.log("existing account connected.\n");
  
    // Parse the compiled contract files
    const compiledSierra = json.parse(
      fs
        .readFileSync("target/dev/swmf_nft.contract_class.json")
        .toString("ascii")
    );
    const compiledCasm = json.parse(
      fs
        .readFileSync(
          "target/dev/swmf_nft.compiled_contract_class.json"
        )
        .toString("ascii")
    );
  
    //**************************************************************************************** */
    // Since we already have the classhash we will be skipping this part
    // Declare the contract
  
    const ch = hash.computeSierraContractClassHash(compiledSierra);
    console.log("Class hash calc =", ch);
    const compCH = hash.computeCompiledClassHash(compiledCasm);
    console.log("compiled class hash =", compCH);
    const declareResponse = await account0.declare({
      contract: compiledSierra,
      casm: compiledCasm,
    });
    const contractClassHash = declareResponse.class_hash;
  
    // Wait for the transaction to be confirmed and log the transaction receipt
    const txR = await provider.waitForTransaction(
      declareResponse.transaction_hash
    );
    console.log("tx receipt =", txR);
  
    //**************************************************************************************** */
  
  
    console.log("✅ Test Contract declared with classHash =", contractClassHash);
  
    console.log("Deploy of contract in progress...");
    const { transaction_hash: th2, address } = await account0.deployContract({
      classHash: contractClassHash,
      constructorCalldata: [],
    });
    console.log("🚀 contract_address =", address);
    // Wait for the deployment transaction to be confirmed
    await provider.waitForTransaction(th2);
  
    console.log("✅ Test completed.");
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  
  //Deployed Address
  // Updated deployed contract_address on Sepolia : 0x2562588faadb5a94487114addfed2f9b5c293bed8f814d9fc791b89eec4a195 on sepolia