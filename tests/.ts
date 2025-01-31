import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test insurance fee operations",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('travel-insurance', 'get-insurance-fee', [], deployer.address),
            Tx.contractCall('travel-insurance', 'update-insurance-fee', [types.uint(200)], deployer.address),
            Tx.contractCall('travel-insurance', 'update-insurance-fee', [types.uint(300)], user1.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), types.uint(100));
        block.receipts[1].result.expectOk();
        block.receipts[2].result.expectErr(types.uint(100)); // err-owner-only
    }
});

Clarinet.test({
    name: "Test policy purchase and claim flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('travel-insurance', 'purchase-policy', [
                types.uint(100), // start date
                types.uint(200), // end date
                types.ascii("New York") // destination
            ], user1.address),
            
            Tx.contractCall('travel-insurance', 'file-claim', [
                types.uint(1), // policy id
                types.ascii("Flight cancelled"), // reason
                types.uint(500) // claim amount
            ], user1.address),
            
            Tx.contractCall('travel-insurance', 'approve-claim', [
                types.uint(1)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        block.receipts[2].result.expectOk();
    }
});
