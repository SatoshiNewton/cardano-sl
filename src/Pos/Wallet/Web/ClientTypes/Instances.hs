{-# LANGUAGE TypeFamilies #-}

-- | Instances for client types

module Pos.Wallet.Web.ClientTypes.Instances () where

import           Universum

import qualified Data.ByteArray                       as ByteArray
import qualified Data.ByteString                      as BS
import           Data.Text                            (splitOn)
import           Formatting                           (build, int, sformat, (%))
import qualified Serokell.Util.Base16                 as Base16
import           Servant.API                          (FromHttpApiData (..))
import           Servant.Multipart                    (FromMultipart (..), lookupFile,
                                                       lookupInput)

import           Pos.Core                             (Address, Coin, decodeTextAddress,
                                                       mkCoin)
import           Pos.Crypto                           (PassPhrase, passphraseLength)
import           Pos.Util.Servant                     (FromCType (..), OriginType,
                                                       ToCType (..))
import           Pos.Wallet.Web.ClientTypes.Functions (addressToCId, mkCTxId)
import           Pos.Wallet.Web.ClientTypes.Types     (AccountId (..), CAccountId (..),
                                                       CElectronCrashReport (..),
                                                       CId (..), CPassPhrase (..), CTxId)

----------------------------------------------------------------------------
-- Convertions
----------------------------------------------------------------------------

type instance OriginType CPassPhrase = PassPhrase

-- These two instances nearly duplicate `instance Bi PassPhrase`
-- in `Pos.Binary.Crypto`.
instance FromCType CPassPhrase where
    decodeCType (CPassPhrase text) = do
        bs <- Base16.decode text
        let bl = BS.length bs
        -- Currently passphrase may be either 32-byte long or empty (for
        -- unencrypted keys).
        if bl == 0 || bl == passphraseLength
            then pure $ ByteArray.convert bs
            else fail . toString $ sformat
                 ("Expected password length 0 or "%int%", not "%int)
                 passphraseLength bl

instance ToCType CPassPhrase where
    encodeCType = CPassPhrase . Base16.encode . ByteArray.convert


type instance OriginType CAccountId = AccountId

instance FromCType CAccountId where
    decodeCType (CAccountId url) =
        case splitOn "@" url of
            [part1, part2] -> do
                aiWId  <- addressToCId <$> decodeTextAddress part1
                aiIndex <- maybe (Left "Invalid wallet index") Right $
                            readMaybe $ toString part2
                return AccountId{..}
            _ -> Left "Expected 2 parts separated by '@'"

instance ToCType CAccountId where
    encodeCType = CAccountId . sformat build



----------------------------------------------------------------------------
-- Servant
----------------------------------------------------------------------------

instance FromHttpApiData Coin where
    parseUrlPiece = fmap mkCoin . parseUrlPiece

instance FromHttpApiData Address where
    parseUrlPiece = decodeTextAddress

instance FromHttpApiData (CId w) where
    parseUrlPiece = fmap addressToCId . decodeTextAddress

instance FromHttpApiData CAccountId where
    parseUrlPiece = fmap CAccountId . parseUrlPiece

-- FIXME: unsafe (temporary, will be removed probably in future)
-- we are not checking whether received Text is really valid CTxId
instance FromHttpApiData CTxId where
    parseUrlPiece = pure . mkCTxId

instance FromHttpApiData CPassPhrase where
    parseUrlPiece = pure . CPassPhrase


instance FromMultipart CElectronCrashReport where
    fromMultipart form = do
        let look t = lookupInput t form
        CElectronCrashReport
          <$> look "ver"
          <*> look "platform"
          <*> look "process_type"
          <*> look "guid"
          <*> look "_version"
          <*> look "_productName"
          <*> look "prod"
          <*> look "_companyName"
          <*> lookupFile "upload_file_minidump" form
