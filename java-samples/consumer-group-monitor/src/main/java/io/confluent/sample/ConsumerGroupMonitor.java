package io.confluent.sample;

import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.PartitionInfo;
import org.apache.kafka.common.TopicPartition;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.*;

/**
 *
 */
public class ConsumerGroupMonitor {
    static final String PROPERTIES_FILE_NAME = "consumer.properties";
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

        Set<TopicPartition> tps = new HashSet<>();
        try(KafkaConsumer<Integer, Order> consumer = new KafkaConsumer<>(props)){
            while(true) {
                List<PartitionInfo> partitionInfos = consumer.partitionsFor(TOPIC);
                System.out.println("FOUND " + partitionInfos.size() + " PARTITIONS");
                tps.clear();
                for (PartitionInfo info : partitionInfos) {
                    tps.add(new TopicPartition(TOPIC, info.partition()));
                }

                Map<TopicPartition, Long> endOffsets = consumer.endOffsets(tps);
                System.out.println("END OFFSET MAP: " + endOffsets);

                Map<TopicPartition, OffsetAndMetadata> committedOffsets = consumer.committed(tps);
                System.out.println("COMMITTED OFFSETS MAP: " + committedOffsets);

                for (TopicPartition tp : tps) {
                    if (!endOffsets.containsKey(tp)) {
                        System.out.println("WARNING could not get end offset for " + tp + ". Will try again later.");
                        continue;
                    }
                    if (!committedOffsets.containsKey(tp)) {
                        System.out.println("WARNING could not get committed offset for " + tp + ". Will try again later.");
                        continue;
                    }

                    long end = endOffsets.get(tp);
                    long committed = committedOffsets.get(tp).offset();
                    if (committed == end) {
                        System.out.println(tp + " is caught up to end offset: " + end);
                    } else {
                        System.out.println(tp + " consumed " + committed + "/" + end);
                    }
                }
                try {
                    Thread.sleep(4000);
                } catch(InterruptedException x){
                    System.out.println("Exiting");
                    break;
                }
            }
        }

    }
}
