final dynamic privacy_notice_config = {
  "name": "PRIVACYNOTICE",
  "initialPage": "privacyNotice",
  "order": 7,
  "version": 1,
  "disabled": false,
  "isSelected": true,
  "flows": [
    {
      "screenType": "TEMPLATE",
      "name": "privacyNotice",
      "heading": "PRIVACY_NOTICE",
      "proceedLabel": "PROCEED",
      "body": [
        {"format": "text", "value": "APP_PRIVACY_NOTICE_PARAGRAPH_1"},
        {"format": "text", "value": "APP_PRIVACY_NOTICE_PARAGRAPH_2"},
        {"format": "text", "value": "APP_PRIVACY_NOTICE_PARAGRAPH_3"},
        {"format": "text", "value": "APP_PRIVACY_NOTICE_PARAGRAPH_4"},
        {"format": "heading", "value": "APP_PRIVACY_NOTICE_EXPLAINS_HEADING"},
        {"format": "bullet", "value": "APP_PRIVACY_NOTICE_BULLET_1"},
        {"format": "bullet", "value": "APP_PRIVACY_NOTICE_BULLET_2"},
        {"format": "bullet", "value": "APP_PRIVACY_NOTICE_BULLET_3"},
        {"format": "bullet", "value": "APP_PRIVACY_NOTICE_BULLET_4"},
        {"format": "bullet", "value": "APP_PRIVACY_NOTICE_BULLET_5"},
        {"format": "text", "value": "APP_PRIVACY_NOTICE_WEBSITE_TEXT"},
        {
          "format": "heading",
          "value": "APP_PRIVACY_NOTICE_OFFICE_ADDRESS_HEADING"
        },
        {
          "format": "text",
          "value": "APP_PRIVACY_NOTICE_UK_HEADING",
          "bold": true
        },
        {"format": "text", "value": "APP_PRIVACY_NOTICE_UK_ADDRESS"},
        {
          "format": "text",
          "value": "APP_PRIVACY_NOTICE_NIGERIA_HEADING",
          "bold": true
        },
        {"format": "text", "value": "APP_PRIVACY_NOTICE_NIGERIA_ADDRESS"},
        {"format": "text", "value": "APP_PRIVACY_NOTICE_CONTACT_TEXT"},
        {"format": "bullet", "value": "APP_PRIVACY_NOTICE_EMAIL_1"},
        {"format": "bullet", "value": "APP_PRIVACY_NOTICE_EMAIL_2"}
      ]
    }
  ]
};
