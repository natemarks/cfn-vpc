from taskcat.testing import CFNTest


def test_topic():
    test = CFNTest.from_file(input_file='./.taskcat.yml')
    with test as stacks:
        # Calling 'with' or 'test.run()' will deploy the stacks.
        for stack in stacks:
            print(f"Testing {stack.name}")
            topic_name = ""
            for output in stack.outputs:
                if output.key == "NotificationTopic":
                    topic_name = output.value
                    break
            assert "gggtopic" in topic_name
            print(f"Created bucket: {topic_name}")