import unittest
from lambda_function import ingestUrl
import responses
import json


class testFetch(unittest.TestCase):
    @responses.activate
    def testValidUrl(self):
        """
        Tests that a valid url returns an exit code 0, as well as some json data
        """

        url = "https://json.json/valid.json"
        with open('testFiles/validJson.json') as json_file:
            data = json.load(json_file)
        responses.add(responses.GET, url, json=data, status=200)
        output = ingestUrl(url)
        self.assertEqual(data, json.loads(output))

    @responses.activate
    def testInvalidUrl(self):
        """
        Tests that a invalid url returns an exit code 10
        """

        url = "https://json.json/404.json"
        responses.add(responses.GET, url, status=404)
        with self.assertRaises(SystemExit) as cm:
            ingestUrl(url)
        self.assertEqual(cm.exception.code, 10)

    def testTimeout(self):
        """
        Tests that connection timing out returns an exit code 11 after 10s
        """

        url = "https://google.com:81"
        with self.assertRaises(SystemExit) as cm:
            ingestUrl(url)
        self.assertEqual(cm.exception.code, 11)

    def testConnectionError(self):
        """
        Tests that connection error returns an exit code 11
         """

        url = "https://json.json/con-error.json"
        with self.assertRaises(SystemExit) as cm:
            ingestUrl(url)
        self.assertEqual(cm.exception.code, 11)

    @responses.activate
    def testMalformedJson(self):
        """
        Tests that a malformed json returns an exit code 20
        """
        url = "https://json.json/invalid.json"
        with open('testFiles/invalidJson.json') as file:
            data = file.read()
        responses.add(responses.GET, url,
                      body=data, status=200)
        with self.assertRaises(SystemExit) as cm:
            ingestUrl(url)
        self.assertEqual(cm.exception.code, 20)


if __name__ == '__main__':
    unittest.main()
