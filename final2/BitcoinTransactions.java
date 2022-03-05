/**
 *
 * @author Ornela Danushi
 */


package P2PSB;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;
import org.neo4j.driver.AuthTokens;
import org.neo4j.driver.Driver;
import org.neo4j.driver.GraphDatabase;
import org.neo4j.driver.Record;
import org.neo4j.driver.Result;
import org.neo4j.driver.Session;
import org.neo4j.driver.Transaction; 


public class BitcoinTransactions{
    static Driver driver = GraphDatabase.driver("bolt://localhost:7687", 
        AuthTokens.basic("neo4j", "grafico"));

    static String transactionsFile = "transactions";	    
    static String inputsFile = "inputs";    
    static String outputsFile = "outputs";    

    static HashMap<Integer, Long> address_UTXO = new HashMap<>();    
    static HashMap<Integer, TreeSet<Integer>> tx_addresses = new HashMap<>();
    static HashMap<Integer, TreeSet<Integer>> addresses_passwords = new HashMap<>();

    

    public static void startDB(){
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                tx.run( "MATCH (n) DETACH DELETE n" );
                System.out.println("Pulizia DB vecchio");
                return "";
            });			
        }
        
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> { // create nodes from csv files 
                tx.run(
                    "LOAD CSV FROM 'file:///"+transactionsFile+".csv' AS row " 
                    +"CREATE (t:Transaction {transactionID: toInteger(row[0]), "
                    + "blockID: toInteger(row[1]), marked: false, "
                    + "in: 0, input_list: [], out: 0, output_list: []}) "
                );
                System.out.println("Salvataggio delle transazioni");

                tx.run(
                    "LOAD CSV FROM 'file:///"+inputsFile+".csv' AS row "
                    +"CREATE (i:Input {inputID: toInteger(row[0]), "
                    + "transactionID: toInteger(row[1]), "
                    + "sigID: toInteger(row[2]), "
                    + "outputID: toInteger(row[3]), marked: false}) "
                );
                System.out.println("Salvataggio degli input");

                tx.run(
                    "LOAD CSV FROM 'file:///"+outputsFile+".csv' AS row " 
                    +"CREATE (o:Output {outputID: toInteger(row[0]), "
                    + "transactionID: toInteger(row[1]), "
                    + "pkID: toInteger(row[2]), "
                    + "value: toInteger(row[3]), marked: false}) "
                );
                System.out.println("Salvataggio degli output");
                
                return "";
            });			
        }

        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> { 
                tx.run(
                    "MATCH (i:Input),(t:Transaction) " 
                    +"WHERE i.transactionID = t.transactionID " 
                    +"CREATE (i)-[:appeared_in]->(t) "             
                );
                System.out.println("Individuazione relazioni tra input e transazione");
                
                tx.run(
                    "MATCH (o:Output), (t:Transaction) " 
                    +"WHERE o.transactionID = t.transactionID "
                    +"CREATE (o)-[:appeared_from]->(t) "              
                );
                System.out.println("Individuazione relazioni tra output e transazione");

                tx.run(
                    "MATCH (i:Input), (o:Output) " 
                    +"WHERE i.sigID = o.pkID AND i.outputID = o.outputID " 
                    +"CREATE (i)-[:used_with]->(o) "              
                );
                System.out.println("Individuazione relazioni tra input e output");
            
                return "";
            });		
            //MATCH (t:Transaction) RETURN count(distinct t) --> 216'626
            //MATCH (i:Input) RETURN count(distinct i) --> 292'427 = appeared_in
            // inputs > transactions     
            //MATCH (o:Output) RETURN count(distinct o) --> 264'310 = appeared_from
            // outputs > transactions  
            // inputs > outputs --> there are reward bitcoins
            //MATCH p=()-[r:used_with]->() RETURN count(distinct p) --> 192'406 = used_with
        }
    }
    
    
    public static void deleteInconsistentData(){

        // conteggio bilancio di ciascuna transazione
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> { 
        
            tx.run(
                "MATCH (t:Transaction)<-[:appeared_in]-(i:Input)-[:used_with]->(o:Output)\n" 
                +"WHERE (i.outputID = o.outputID) AND NOT (o.outputID IN t.input_list)\n"
                +"SET t.in = t.in + o.value, t.input_list = t.input_list + o.outputID"              
            );
            tx.run(
                "MATCH (t:Transaction)<-[:appeared_from]-(o:Output)\n" 
                +"WHERE NOT (o.outputID IN t.output_list)\n"
                +"SET t.out = t.out + o.value, t.output_list = t.output_list + o.outputID "
            );
            
            return "";
            });
        }
        //MATCH (t:Transaction) WHERE t.in < t.out AND t.in <> 0 return count(distinct t)
        //count(distinct t) --> 838
        // significa che ho transazioni che hanno dato bitcoin in output più di quelli che li avevano
        // ricevuti in input
        // queste transazioni sono considerate errate e quindi da dover eliminare
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> { //group transactions for the block belonging in
        
            tx.run(
                "MATCH (t:Transaction) WHERE t.in < t.out AND t.in <> 0 "
                + "DETACH DELETE t"
            );
            tx.run( "MATCH (i:Input) \n" 
                +"WHERE not ()-[*]-(i) \n" 
                +"DELETE i"
            );                
            tx.run( "MATCH (o:Output) \n" 
                +"WHERE not ()-[*]-(o) \n" 
                +"DELETE o"
            );   
            tx.run( "MATCH (i:Input)-[r:used_with]->(o:Output)\n"
                +"WHERE not( ()-[*]->(i) ) AND not( ()<-[*]-(o) )\n"
                +"DETACH DELETE r,o,i "
            );
            System.out.println("Rimozione transazioni e elementi collegati che non rispettano il corretto bilancio");

            return "";
            });
        }
        
 
        // delete those transactions which do not follow the 6 confirmation rule
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                tx.run( "MATCH p = \n" 
                    +"    (:Input)-[:appeared_in]->(t:Transaction)<-[:appeared_from]-(:Output)<-[:used_with]-\n" 
                    +"    (:Input)-[:appeared_in]->(t1:Transaction)<-[:appeared_from]-(:Output)<-[:used_with]-\n" 
                    +"    (:Input)-[:appeared_in]->(t2:Transaction)<-[:appeared_from]-(:Output)<-[:used_with]-\n" 
                    +"    (:Input)-[:appeared_in]->(t3:Transaction)<-[:appeared_from]-(:Output)<-[:used_with]-\n" 
                    +"    (:Input)-[:appeared_in]->(t4:Transaction)<-[:appeared_from]-(:Output)<-[:used_with]-\n" 
                    +"    (:Input)-[:appeared_in]->(t5:Transaction)<-[:appeared_from]-(:Output)<-[:used_with]-\n" 
                    +"    (:Input)\n" 
                    +"WHERE \n" 
                    +"    t.blockID<>t1.blockID AND t.blockID<>t2.blockID AND t.blockID<>t3.blockID AND\n" 
                    +"    t.blockID<>t4.blockID AND t.blockID<>t5.blockID AND\n" 
                    +"    t1.blockID<>t2.blockID AND t1.blockID<>t3.blockID AND t1.blockID<>t4.blockID AND\n" 
                    +"    t1.blockID<>t5.blockID AND\n" 
                    +"    t2.blockID<>t3.blockID AND t2.blockID<>t4.blockID AND t2.blockID<>t5.blockID AND\n" 
                    +"    t3.blockID<>t4.blockID AND t3.blockID<>t5.blockID AND \n" 
                    +"    t4.blockID<>t5.blockID\n" 
                    +"FOREACH (n IN nodes(p) | SET n.marked = true) "
                );                
                System.out.println("Individuazione transazioni accettate con almeno 6 regole di conferma");
                return "";
            });			
        }
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                tx.run( "MATCH (t:Transaction) \n" 
                    +"WHERE t.marked = false \n" 
                    +"DETACH DELETE t"
                ); 
                tx.run( "MATCH (i:Input) \n" 
                    +"WHERE not ()-[*]-(i) \n" 
                    +"DELETE i"
                );                
                tx.run( "MATCH (o:Output) \n" 
                    +"WHERE not ()-[*]-(o) \n" 
                    +"DELETE o"
                );   
                tx.run( "MATCH (i:Input)-[r:used_with]->(o:Output)\n"
                    +"WHERE not( ()-[*]->(i) ) AND not( ()<-[*]-(o) )\n"
                    +"DETACH DELETE r,o,i "
                );
                System.out.println("Rimozione transazioni e elementi collegati non accettate con almeno 6 regole di conferma");
                return "";
            });		            
        }
        

        //check to discover if there is double spending
        //means that if there is the same transaction in more than one block
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> { //group transactions for the block belonging in
                Result result =(Result) tx.run(
                    "MATCH (t:Transaction)\n" 
                    +"RETURN t.blockID " 
                );
                System.out.println("Individuazione blocchi di appartenenza delle transazioni");
                
                Set<Integer> block = new TreeSet<>();
                while(result.hasNext()){
                    Record record = result.next();   
                    int blockID = record.get(0).asInt();                    
                    block.add(blockID);
                }

                System.out.println("Salvataggio dei blocchi con le corrispondenti relazioni");                
                Iterator<Integer> itr = block.iterator();
                while(itr.hasNext()){
                    String query = "CREATE (b:Block{blockID:"+itr.next()+ "})";
                    tx.run( query );
                }

                tx.run("MATCH (b:Block), (t:Transaction)\n"
                    +"WHERE b.blockID=t.blockID\n"
                    +"CREATE (t)-[:belongs_to]->(b)"                        
                );
                return "";
            });			
        }
        //MATCH p=()-[r:belongs_to]->() RETURN count(p), count(distinct p)
        //count(p) = 67'953 = count(distinct p)
        // --> each transaction belongs to a different block        
        
        //MATCH (t:Transaction) RETURN count(distinct t.blockID), count(t.transactionID), max(t.blockID), min(t.blockID)
        //count(distinct t.blockID) = 32'245	
        //count(t.transactionID) = 67'953
        //max(t.blockID) = 100'006
        //min(t.blockID) = 9
        //NOTE: the ending block is at height 100'001
        //NOTE: the genesis block, the first ever created, is at height 0
        //NOTE: block reward is of 5'000'000'000 Satoshis, while we have the maximum value of 9'000'000'000'000 max(o.value)
        // this beacuse there are also fees included along the time
                
        //match (o:Output) return count(o.value), o.value
        
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> { 
                Result result =(Result) tx.run(
                    "MATCH (b1:Block)<-[:belongs_to]-(t:Transaction), (b2:Block)-[:belongs_to]-(t1:Transaction)\n" 
                    +"WHERE t.transactionID=t1.transactionID AND b1.blockID<>b2.blockID\n" 
                    +"RETURN count( distinct t.transactionID) " 
                );
                while(result.hasNext()){
                    Record record = result.next();   
                    int count = record.get(0).asInt();                    
                    System.out.println("There are "+count+"same transaction in different blocks.");
                }
        
                return "";
            });			
        }
   
        
    }
    public static void computeTotUTXO(){
        /*
        UTXO = bitcoins sent to an address and not spent in any transaction
        is like a cache useful to check validity of new transactions
        find all the unspent outputs of an address
        wallet = user balance = scan the blockchain and compute the UTXOs of a user               
        
        somma il valore degli output di una transazione,
        i quali non hanno collegamenti con un input e sono per cui non spesi
        di tutti questi, si restituisce per ogni indirizzo il valore massimo
        */
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                Result result =(Result) tx.run( "MATCH (o:Output), (t:Transaction)\n" 
                    +"WHERE NOT(()-[:used_with]->(o)) AND o.transactionID = t.transactionID\n" 
                    +"with sum(o.value) as s, o as o, t as t\n" 
                    +"RETURN o.transactionID, t.blockID, o.outputID, o.pkID as address, max(s) "
                );
                System.out.println("Individuazione massimo UTXO per ciascun indirizzo");
                
                /*
                System.out.println("Stampa di 5 UTXOs per indirizzo");
                int count=0;
                while(result.hasNext() && count<5){
                    Record record = result.next();
                    System.out.print("\tTransactionID: " +record.get(0) );
                    System.out.print("\tBlockID: " +record.get(1) );
                    System.out.print("\tOutputID: " +record.get(2) );
                    System.out.print("\tAddress: " +record.get(3) );
                    System.out.println("\tMax UTXO value: " +record.get(4) );
                    count++;
                }
                */

                int transactionID=-1, blockID=-1, outputID=-1, pkID=-1;
                long max= 0L, max_pkID=0L;                 
                while(result.hasNext()){
                    Record record = result.next();
                    pkID = (int) record.get(3).asInt();
                    long temp_max = (long) record.get(4).asLong();                    
                    if( temp_max > max ){
                        transactionID = record.get(0).asInt();
                        blockID = record.get(1).asInt();
                        outputID = record.get(2).asInt();
                        max = temp_max;
                        max_pkID = pkID;
                    }
                    address_UTXO.putIfAbsent(pkID, temp_max);
                }     
                
                System.out.println("The highest associated UTXO value of: "+max+" belongs to"
                    + " transactionID "+transactionID + " of the blockID "+blockID
                    + " with outputID "+outputID+" and address "+ max_pkID);
                return "";
            });			
        }

    }
    public static void clusterAddresses(){
        /*
        each cluster resulting from the application of these heuristics, corresponds
        to an entity which controls all the addresses in that cluster.
        */
        
        // first type of cluster: link together all the reward inputs
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                tx.run( "CREATE (a:award_cluster{name:\"AWARD_CLUSTER\"}) ");
                System.out.println("Creazione nodo dell'AWARD CLUSTER");
                
                tx.run(
                    "MATCH (i:Input{outputID:-1, sigID:0})-[:appeared_in]->(:Transaction)\n" 
                    +"WHERE NOT(()-[*]->(i)) \n" 
                    +"MATCH (a:award_cluster)\n" 
                    +"MERGE (a)-[:award_block]-(i) "              
                );
                System.out.println("Creazione relazioni col nodo dell'AWARD CLUSTER");
                return "";
            });			
        }
        
        // match (i:Input) return count( distinct i.sigID) --> 110'316 different private keys
        // match (i:Output) return count( distinct i.pkID) --> 174'702 different public keys
        
        /*
        heuristic1: link common input addresses together
        all addresses used as input to a transaction are controlled by the same entity, 
        they must be signed, so it is likely that they belong to the same user
        that user knows all the private keys corresponding to those inputs        
                
        if 2 or more addresses are inputs to the same transaction then
        they are controlled by the same user
        
        all pk in inputs(t) are controlled by the same user
        */

        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                Result result =(Result) tx.run( "MATCH (t:Transaction), (i:Input), (o:Output)\n" 
                    +"WHERE t.transactionID=i.transactionID=o.transactionID \n"//AND i.sigID<>0\n" 
                    +"MERGE (i)-[:same_user]-(o) "
                    +"RETURN t.transactionID, o.outputID, o.pkID, i.inputID, i.sigID "
                );
                System.out.println("Creazione relazioni per l'identificazione degli USERS CLUSTER");
                
                while(result.hasNext()){
                    Record record = result.next();   
                    /*
                    System.out.print("\tTransactionID: " +record.get(0) );
                    System.out.print("\tOutputID: " +record.get(1) );
                    System.out.print("\tAddress: " +record.get(2) );
                    System.out.print("\tInputID: " +record.get(3) );
                    System.out.println("\tPWD: " +record.get(4) );
                    */
                    int userAddress = record.get(2).asInt();
                    int userPwd = record.get(4).asInt();                    
                    addresses_passwords.putIfAbsent(userAddress, new TreeSet<>());
                    addresses_passwords.get(userAddress).add(userPwd);

                    int txID = record.get(0).asInt();
                    tx_addresses.putIfAbsent(txID, new TreeSet<>());
                    tx_addresses.get(txID).add(userAddress);
                    
                    
                }
                
                return "";
            });			
        }
        
        /*
        take into account transitivity
        i.e. 2 cluster are merged if they contain at least 2 addresses which appear
        together as input in at least one transaction.
        NOTA: viene soddisfatta con la costruzione dei cammini così fatti
        vedere la versione grafica per convincersi
        */

        
        /*
        heuristic2: serial control heuristic
        the output address of a transaction with a single input and a single output
        is usually controlled by the same entity owning the input address
        
        è un caso base della heuristic1
        quindi è già realizzata
        si riferisce anche ai nodi di rewarding
        */
        
    }
    
    public static void printClustersInfo(){
        /*
        System.out.println("Stampa di 5 indirizzi di utenti con relative password segrete e massimo UTXO");
        int count=0;                
        for (Map.Entry<Integer, TreeSet<Integer>> ee : addresses_passwords.entrySet()) {
            Integer key = ee.getKey();
            System.out.println("UserAddress: "+key);                    
            TreeSet<Integer> values = ee.getValue();                    
            Iterator<Integer> itr = values.iterator();
            System.out.print("Password usate:");
            while(itr.hasNext()){
                System.out.print("\t"+itr.next());
            }
            System.out.println();
            System.out.println("max UTXO: "+address_UTXO.get(key));
            count++;
            if( count==5 ){
                break;
            }
        }
        */
        System.out.println();
        
        // find the address who has the most unspent bitcoins = max UTXO
        Long max_value = 0L;
        Integer key_associated = 0;
        for (Map.Entry<Integer, Long> ee : address_UTXO.entrySet()) {
            Integer key = ee.getKey();
            Long value = ee.getValue();                    
            if( value>max_value ){
                max_value = value;
                key_associated = key;
            }
        }
        // find the lowest numerical address owned by the same user of that owning the same key just discovered
        // and compute the total of UTXO owned by that user on several addresses
        Long tot_value = 0L;
        for (Map.Entry<Integer, TreeSet<Integer>> ee : tx_addresses.entrySet()) {
            TreeSet<Integer> values = ee.getValue();                    
            if( values.contains(key_associated)){
                Iterator<Integer> itr = values.iterator();
                while(itr.hasNext()){
                    int key_compare = itr.next();
                    if( key_compare < key_associated){
                        key_associated = key_compare;
                    }
                    Long val_returned = address_UTXO.get(key_compare);
                    if( val_returned!=null ){
                        tot_value += val_returned;                        
                    }
                }    
            }
        }
        System.out.println("Lowest address: "+key_associated+"\tTot UTXOs owned: "+tot_value+"\tof which the max UTXO owned: "+max_value);
        // 139898
        
        final Integer k_a = key_associated;
        //give the ID of the transaction sending the greatest amount of bitcoins to this entity
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                String query = "MATCH (o:Output{pkID:"+k_a.toString()+"})<-[:used_with]-(i:Input)\n" 
                    +"MATCH p=(oo:Output)<-[:same_user]-(i)\n" 
                    +"WITH max(oo.value) as m, oo as oo\n" 
                    +"RETURN distinct(oo.transactionID) ";
                Result result =(Result) tx.run( query);                
                while(result.hasNext()){
                    Record record = result.next();   
                    System.out.println("TransactionID sending the greatest amount of bitcoins: " +record.get(0) );
                }                
                return "";
            });			
        }
        
        
        /*
        consider the clusterized transaction graph, i.e. the graph whose
        nodes correspond to clusters, i.e. entities, and whose edges are such
        that there is an edge between two clusters iff there is a transaction
        with an input address in the first cluster and an output address in
        the second cluster. Find the length of the longest payment path in
        this graph.

        // procedura corretta ma ci impiega troppo tempo
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                Result result =(Result) tx.run( "MATCH p = (:Transaction)-[]-(:Transaction)\n" 
                    +"RETURN length(p) ORDER BY length(p) DESC LIMIT 1");  
                while(result.hasNext()){
                    Record record = result.next();   
                    System.out.print("Length of the longest payment path: " +record.get(0) );
                }                
                return "";
            });			
        }
        */
        
        try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                //get the # of times this path is used in sequence
                Result result =(Result) tx.run( "MATCH p = (:Input)-[:used_with]->(:Output)<-[:same_user]-(:Input)\n" 
                    +"WITH count(*) as count\n" 
                    +"RETURN max(count)");                
                while(result.hasNext()){
                    Record record = result.next();   
                    System.out.println("Length of the longest payment path: " +record.get(0).asInt()*3 );
                }                
                return "";
            });			
        }
        
        /*
        are the proposed clustering methods accurate? 
        
        List at least one 
        potential source of false positives (clustering addresses which aren’t
        actually owned by the same entity) 
        and one source of false negatives (failing to cluster addresses which 
        actually are owned by the same entity) 
        in this method. What strategies could you use to make your
        clustering more accurate?
                              
        */
        Integer address1=0, address2=0;
        for (Map.Entry<Integer, TreeSet<Integer>> e1 : addresses_passwords.entrySet()) {
            Integer key1 = e1.getKey();
            TreeSet<Integer> values1 = e1.getValue();                    
            Iterator<Integer> itr1 = values1.iterator();
            
            while(itr1.hasNext() && address1==0 && address2==0){
                Integer val1 = itr1.next();
                
                for (Map.Entry<Integer, TreeSet<Integer>> e2 : addresses_passwords.entrySet()) {
                    Integer key2 = e2.getKey();
                    if( !Objects.equals(key1, key2) ){
                        
                        TreeSet<Integer> values2 = e2.getValue();                    
                        Iterator<Integer> itr2 = values2.iterator();
                        
                        while(itr2.hasNext() && address1==0 && address2==0){
                            Integer val2 = itr2.next();
                            
                            if( Objects.equals(val2, val1) && val2!=0 && val1!=0 ){
                                System.out.println("Found a false negative!");
                                address1 = key1;
                                address2 = key2;
                            }
                        }
                        if( address1!=0 && address2!=0){ break; }
                    }
                }
            }
            if( address1!=0 && address2!=0){ break; }
        }
        if( address1!=0 && address2!=0){                       
            final Integer add1=address1, add2=address2;
            System.out.println("NOTE: Was found a false negative between these public addresses: "+add1+" and "+add2);
            try ( Session session = driver.session() ){
            session.writeTransaction((Transaction tx) -> {
                String query = "MATCH (o1:Output{pkID:"+Integer.toString(add1)+"}), (o2:Output{pkID:"+Integer.toString(add2)+"})\n"+
                    "RETURN o1.transactionID, o2.transactionID";
                Result result =(Result) tx.run( query );                
                while(result.hasNext()){
                    Record record = result.next();   
                    System.out.println("They refer to different transactions: " +record.get(0).asInt() + " and " +record.get(1).asInt());
                }                
                return "";
            });			
        }

        }
        System.out.println();
        
    }

    public static void main( String[] args ){
        
        startDB();
        deleteInconsistentData();
        computeTotUTXO();
        clusterAddresses();
        
        printClustersInfo();
        
        driver.close();
    }

    
}



