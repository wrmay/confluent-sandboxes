package io.confluent.sample;

import org.apache.kafka.clients.consumer.Consumer;
import org.apache.kafka.clients.consumer.ConsumerRebalanceListener;
import org.apache.kafka.common.TopicPartition;

import java.time.Duration;
import java.util.Collection;

public class CommitOnRevokeRebalanceHandler implements ConsumerRebalanceListener {
    private Consumer<?,?> consumer;
    public CommitOnRevokeRebalanceHandler(Consumer<?,?> consumer){
        this.consumer = consumer;
    }

    @Override
    public void onPartitionsRevoked(Collection<TopicPartition> collection) {
        for(TopicPartition tp: collection){
            System.out.println(tp + " REVOKED");
        }
        System.out.println("COMMITTING OFFSETS");
        try {
            this.consumer.commitSync(Duration.ofSeconds(10));
            System.out.println("OFFSETS COMMITED");
        } catch(RuntimeException x){
            System.out.println("WARNING: Commit on revoke failed. Duplicate message delivery could occur.");
        }
    }

    @Override
    public void onPartitionsAssigned(Collection<TopicPartition> collection) {
        // do nothing
    }
}
