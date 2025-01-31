import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test multi-policy purchase and management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Purchase first policy
            Tx.contractCall('travel-insurance', 'purchase-policy', [
                types.uint(100),
                types.uint(200),
                types.ascii("New York")
            ], user1.address),
            
            // Purchase second policy
            Tx.contractCall('travel-insurance', 'purchase-policy', [
                types.uint(300),
                types.uint(400),
                types.ascii("London")
            ], user1.address),
            
            // Get user policies
            Tx.contractCall('travel-insurance', 'get-user-policies', [
                types.principal(user1.address)
            ], user1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        const policies = block.receipts[2].result.expectOk();
        assertEquals(policies.indexOf(types.uint(0)) !== -1, true);
        assertEquals(policies.indexOf(types.uint(1)) !== -1, true);
    }
});

Clarinet.test({
    name: "Test policy refund functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Purchase policy
            Tx.contractCall('travel-insurance', 'purchase-policy', [
                types.uint(100),
                types.uint(200),
                types.ascii("Paris")
            ], user1.address),
            
            // Request refund
            Tx.contractCall('travel-insurance', 'request-refund', [
                types.uint(0)
            ], user1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
    }
});
