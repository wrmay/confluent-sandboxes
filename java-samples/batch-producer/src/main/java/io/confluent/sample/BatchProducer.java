package io.confluent.sample;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Properties;
import java.util.Random;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;

/**
 *
 */


public class BatchProducer {
    static final String PROPERTIES_FILE_NAME = "producer.properties";
    static final String MESSAGE_COUNT_PROP = "producer.message.count";
    static final String MESSAGE_RATE_PROP = "producer.rate.tps";

    private static final String TOPIC = "orders";

    private static int requiredInt(Properties props, String propName){
        String str = props.getProperty(propName);
        if (str == null){
            System.out.println("Required property \"" + propName + "\" is missing.  Exiting");
            System.exit(1);
        }
        int result= 0;
        try {
            result = Integer.parseInt(str);
        } catch(NumberFormatException x){
            System.out.println("Could not parse \"" + str + "\" (value for \"" + propName + "\") as an integer.  Exiting.");
            System.exit(1);
        }
        return result;
    }

    public static void main(String[] args) {
        File propsFile = new File(PROPERTIES_FILE_NAME);
        if (!propsFile.exists()) {
            System.out.println("Required configuration file \"" + PROPERTIES_FILE_NAME + "\" not present.  Exiting.");
            System.exit(1);
        }

        Properties props = new Properties();
        try (InputStreamReader reader = new InputStreamReader(new FileInputStream(propsFile))) {
            props.load(reader);
        } catch (IOException e) {
            System.out.println("An exception occurred while loading configuration from \""
                    + PROPERTIES_FILE_NAME + "\". Exiting.");
            e.printStackTrace(System.err);
            System.exit(1);
        }

        int messageCount = requiredInt(props, MESSAGE_COUNT_PROP);
        int messageRate = requiredInt(props, MESSAGE_RATE_PROP);
        int intervalNanos = 0;
        if (messageRate > 0){
            intervalNanos = 1000000000 / messageRate;
            if (intervalNanos == 0) {
                System.out.println("This producer does not support message rates > 1000000 tps. Set " + MESSAGE_RATE_PROP + "to 0 to turn off throttling.");
                System.exit(1);
            }
        }
        

        RandomOrderGenerator orderGenerator = new RandomOrderGenerator(new Random());
        Future<RecordMetadata> []allResults = new Future[messageCount];

        KafkaProducer<Integer, Order> producer = new KafkaProducer<>(props);
        try{
            long nextMessageDue = System.nanoTime();
            for (int i=0; i < messageCount; ++i){
                long nanosUntilDue = nextMessageDue - System.nanoTime();
                if (nanosUntilDue < -1 * 5 * 1000000000){
                    System.out.println("Producer cannot maintain the desired rate");
                    System.exit(1);
                } else if (nanosUntilDue > 2 * 1000000){
                    try {
                        Thread.sleep(nanosUntilDue / 1000000);
                    } catch(InterruptedException x){
                        System.out.println("Interrupted.  Exiting");
                        break;
                    }
                } else {
                    Order anOrder = orderGenerator.next();
                    ProducerRecord<Integer, Order> record =
                            new ProducerRecord<>(TOPIC,null, anOrder.getTimestamp().getEpochSecond(), anOrder.getId(),anOrder);
                    allResults[i] = producer.send(record);
                    nextMessageDue += intervalNanos;
                }
            }
        } finally {
            producer.flush();
            producer.close();
        }
        System.out.println(messageCount + " records sent.  Waiting for aks");

        int count = 0;
        for (int i=0; i < messageCount; ++i){
            try {
                RecordMetadata metadata = allResults[i].get();
                System.out.printf("Produced Order to %s-%d@%d%n",
                        metadata.topic(), metadata.partition(), metadata.offset());
                count += 1;
            } catch (InterruptedException e) {
                // if this is moved out of main, it should handle interruption differently
                System.out.println("Interrupted while waiting for acks. Exiting.");
                System.exit(0);
            } catch (RuntimeException | ExecutionException e){
                System.out.println("An error occurred while waiting for acks: " + e.getLocalizedMessage());
            }
        }

        System.out.println("Wrote " + count + " messages");
    }
}
