package io.confluent.sample;

import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.TopicPartition;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.time.Duration;
import java.util.List;
import java.util.Properties;
import java.util.Set;

/**
 *
 */
public class SimpleConsumer {
    static final String PROPERTIES_FILE_NAME = "consumer.properties";
    static final String CONSUMPTION_DELAY_PROP = "batch.consumption.delay.ms";
    private static final String TOPIC = "orders";

    public static void main(String[] args)  {
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

        int consumption_delay = 1000;
        if (props.contains(CONSUMPTION_DELAY_PROP)){
            String errorMsg = "The \"" + CONSUMPTION_DELAY_PROP + "\"property must be a non-negative decimal integer.  Exiting.";
            try {
                int d = Integer.parseInt((String) props.get(CONSUMPTION_DELAY_PROP));
                if (d < 0){
                    System.out.println(errorMsg);
                    System.exit(1);
                }
            } catch (NumberFormatException e ) {
                System.out.println(errorMsg);
                System.exit(1);
            }
        }

        try(KafkaConsumer<Integer, Order> consumer = new KafkaConsumer<>(props)){
            consumer.subscribe(List.of(TOPIC), new CommitOnRevokeRebalanceHandler(consumer));

            while(true){
                Set<TopicPartition> assignment = consumer.assignment();
                System.out.println("ASSIGNMENT: " + assignment);

                ConsumerRecords<Integer, Order> records = consumer.poll(Duration.ofSeconds(2));
                System.out.println("GOT " + records.count() + " records");
//                for(ConsumerRecord<Integer, Order> record: records){
//                    System.out.println("ORDER: " + record.value());
//                }

                System.out.println("SLEEPING");
                try {
                    Thread.sleep(consumption_delay);
                } catch (InterruptedException e) {
                    System.exit(0);
                }
            }
        }

    }
}
