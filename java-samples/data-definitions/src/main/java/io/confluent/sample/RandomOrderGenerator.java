package io.confluent.sample;

/*
 * Note: there is an Avro random data generator but the generated orders don't look good
 * so here we are
 */

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public class RandomOrderGenerator {
    private static final String []nicknames = {
            "Stanley",
            "Sharon",
            "Anthony",
            "Frodo",
            "ChunSing",
            "Jen",
            "Morpheus",
            "Randy",
            "Hieronymous",
            "Coco",
            "Tom",
            "Shaun",
            "Sally"
    };

    private final Random random;
    private final int uniqueItems;
    private final int avgOrderSize;
    private final float itemLikelihood;

    private int nextId;

    private  String randomNickname(){
        int index = random.nextInt(nicknames.length);
        return nicknames[index];
    }

    public RandomOrderGenerator(Random rand){
        this.random = rand;
        this.uniqueItems = menu_items.values().length;
        this.avgOrderSize = 4;
        this.itemLikelihood = (float) this.avgOrderSize / (float) this.uniqueItems;
    }

    public Order next(){
        Order result = new Order();
        result.setId(this.nextId++);
        result.setTimestamp(Instant.now());
        result.setCustomerNickname(randomNickname());
        List<items> itemsList = new ArrayList<>(uniqueItems);
        while(itemsList.isEmpty()){
            for(int i = 0; i < uniqueItems; ++i){
                if (random.nextFloat() <= this.itemLikelihood){
                    items randomItem = new items();
                    randomItem.setItem(menu_items.values()[i]);
                    randomItem.setQuantity(random.nextInt(1,5));
                    itemsList.add(randomItem);
                }
            }
        }
        result.setItems(itemsList);

        return result;
    }
}
