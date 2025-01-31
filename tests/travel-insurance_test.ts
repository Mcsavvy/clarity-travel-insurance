import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test policy date validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Test invalid dates (end before start)
            Tx.contractCall('travel-insurance', 'purchase-policy', [
                types.uint(200),
                types.uint(100),
                types.ascii("Paris")
            ], user1.address),
            
            // Test valid dates
            Tx.contractCall('travel-insurance', 'purchase-policy', [
                types.uint(block.height + 10),
                types.uint(block.height + 100),
                types.ascii("London")
            ], user1.address)
        ]);
        
        block.receipts[0].result.expectErr(types.uint(107)); // err-invalid-dates
        block.receipts[1].result.expectOk();
    }
});

// [Rest of tests remain unchanged]
